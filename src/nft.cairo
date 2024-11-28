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

    fn generate_random_id(address: ContractAddress, token_id: u128) -> ByteArray {
        let minter_felt: felt252 = address.try_into().unwrap();
        let minter_u256: u256 = minter_felt.into();
        let token_u256: u256 = token_id.into();
        let combined = (minter_u256 + token_u256) % 1_u256;
        format!("{}", combined)
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Peer Spok"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "P2P-SPOK"
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            assert(token_id <= self.latest_token_id.read().into(), 'Token ID does not exist');
            let minter = self.token_minter.read(token_id.low);
            let random_id = generate_random_id(minter, token_id.low);
            let svg: ByteArray = build_svg(self.token_minter.read(token_id.low));
            format!(
                "data:application/json,{{\"name\":\"Peer Spok #{random_id}\",\"description\":\"P2P spok.\",\"image\":\"data:image/svg+xml,{svg}\"}}"
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
        let circle_color = format!("hsl({h}, {s}%, {l}%)");

        format!(
            "<svg xmlns='http://www.w3.org/2000/svg' version='1.1' width='320' height='320' viewBox='0 0 320 320'><title>PS Circle</title><circle cx='160' cy='160' r='140' fill='{circle_color}'/><text x='160' y='180' font-family='Arial, sans-serif' font-size='80' font-weight='bold' text-anchor='middle' fill='white'>ps</text></svg>"
        )
    }
}
