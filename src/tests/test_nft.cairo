use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address_global};
use starknet::ContractAddress;

#[starknet::interface]
trait INFT<TContractState> {
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn mint(ref self: TContractState);
}

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn deploy_nft() -> INFTDispatcher {
    let contract = declare("nft").unwrap().contract_class();
    let calldata: Array<felt252> = array![owner().into()];
    let (contract_address, _) = contract.deploy(@calldata).expect('nft deploy failed');
    INFTDispatcher { contract_address }
}

#[test]
fn test_one() {
    let nft: INFTDispatcher = deploy_nft();
    start_cheat_caller_address_global('a guy who likes nouns'.try_into().unwrap());
    nft.mint();
    let token_uri = nft.token_uri(1);
    println!("{token_uri}");
}
