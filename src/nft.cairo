#[starknet::interface]
pub trait IMintable<TContractState> {
    fn mint(ref self: TContractState);
}

#[starknet::contract]
mod nft {
    use crate::bitops::{Bitshift, BitshiftImpl};
    use openzeppelin::introspection::src5::{SRC5Component, SRC5Component::InternalTrait as SRC5InternalTrait};
    use openzeppelin::token::erc721::{
        ERC721Component, interface::IERC721Metadata, interface::IERC721MetadataCamelOnly, interface::IERC721_ID,
        interface::IERC721_METADATA_ID, ERC721HooksEmptyImpl
    };
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess
    };
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,

        // keeps track of the last minted token ID
        latest_token_id: u128,
        // mapping from token ID to minter's address
        // we use the minter's address to generate the token,
        // so even if the NFT is transferred, its appearance remains
        token_minter: Map<u128, ContractAddress>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // not calling self.erc721.initializer as we implement the metadata interface ourselves,
        // just registering the interface with SRC5 component
        self.src5.register_interface(IERC721_ID);
        self.src5.register_interface(IERC721_METADATA_ID);
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Nouns Glasses"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "GLASSES"
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            assert(token_id <= self.latest_token_id.read().into(), 'Token ID does not exist');
            let svg: ByteArray = build_svg(self.token_minter.read(token_id.low));
            format!(
                "data:application/json,{{\"name\":\"Nouns Glasses\",\"description\":\"Glasses. Nounish.\",\"image\":\"data:image/svg+xml,{svg}\"}}"
            )
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelMetadataImpl of IERC721MetadataCamelOnly<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> ByteArray {
            self.token_uri(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl IMintableImpl of super::IMintable<ContractState> {
        fn mint(ref self: ContractState) {
            let token_id = self.latest_token_id.read() + 1;
            self.latest_token_id.write(token_id);

            let minter = get_caller_address();
            self.token_minter.write(token_id, minter);

            self.erc721.mint(minter, token_id.into());
        }
    }

    fn build_svg(address: ContractAddress) -> ByteArray {
        let address: felt252 = address.try_into().unwrap();
        let address: u256 = address.into();
        // hue is 0..360, saturation is 0..100, lightness is 5..95
        // values are generated from the address
        let h = address.low % 361;
        let s = address.high % 101;
        let l = (address.high.shr(12) % 91) + 5;
        let rim_color = format!("hsl({h}, {s}%, {l}%)");

        format!(
            "<svg xmlns='http://www.w3.org/2000/svg' version='1.1' width='320' height='320' viewBox='0 0 320 320' shape-rendering='crispEdges'><title>Noun glasses</title><style>rect.f {{ fill: {rim_color}; }}</style><rect width='100%' height='100%' fill='none'></rect><g><rect width='60' height='60' x='100' y='110' class='f'></rect><rect width='60' height='60' x='170' y='110' class='f'></rect><rect width='10' height='10' x='160' y='130' class='f'></rect><rect width='30' height='10' x='70' y='130' class='f'></rect><rect width='10' height='20' x='70' y='140' class='f'></rect><rect width='20' height='40' x='110' y='120' fill='white'></rect><rect width='20' height='40' x='130' y='120' fill='black'></rect><rect width='20' height='40' x='180' y='120' fill='white'></rect><rect width='20' height='40' x='200' y='120' fill='black'></rect></g></svg>"
        )
    }
}
