use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address_global, stop_cheat_caller_address_global};
use starknet::ContractAddress;

#[starknet::interface]
trait IERC721Metadata<TContractState> {
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
}

#[starknet::interface]
trait IMintable<TContractState> {
    fn mint(ref self: TContractState, reciever_Address: ContractAddress, unique_id: u256, proposal_id: u256);
    fn update_peer_protocol_address(ref self: TContractState, new_address: ContractAddress);
    fn burn(ref self: TContractState, token_id: u256);
}

// Generate the dispatchers automatically
use starknet::class_hash::ClassHash;

#[derive(Drop)]
struct CombinedDispatcher {
    contract_address: ContractAddress,
}

// Use the auto-generated dispatchers
// use IMintableDispatcher;
// use IERC721MetadataDispatcher;

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn protocol_address() -> ContractAddress {
    'protocol'.try_into().unwrap()
}

fn deploy_nft() -> (IMintableDispatcher, IERC721MetadataDispatcher) {
    let contract = declare("nft").unwrap().contract_class();
    let calldata: Array<felt252> = array![
        owner().into(),
        protocol_address().into()  // Set the protocol address
    ];
    let (contract_address, _) = contract.deploy(@calldata).expect('nft deploy failed');
    (
        IMintableDispatcher { contract_address },
        IERC721MetadataDispatcher { contract_address }
    )
}

#[test]
fn test_mint_and_metadata() {
    let (nft, nft_metadata) = deploy_nft();
    
    let receiver = 'test_receiver'.try_into().unwrap();
    let unique_id = 1.into();
    let proposal_id = 1.into();

    // Simulate call coming from protocol contract
    start_cheat_caller_address_global(protocol_address());
    nft.mint(receiver, unique_id, proposal_id);

    let token_uri = nft_metadata.token_uri(1.into());
    println!("Token URI: {token_uri}");
    
    let name = nft_metadata.name();
    println!("Name: {name}");
    
    let symbol = nft_metadata.symbol();
    println!("Symbol: {symbol}");
}

#[test]
fn test_burn() {
    let (nft, _) = deploy_nft();
    
    let receiver = 'test_receiver'.try_into().unwrap();
    
    // Mint from protocol
    start_cheat_caller_address_global(protocol_address());
    nft.mint(receiver, 1.into(), 1.into());
    stop_cheat_caller_address_global();

    // Burn should be called from protocol too
    start_cheat_caller_address_global(protocol_address());
    nft.burn(1.into());
    stop_cheat_caller_address_global();
}

#[test]
fn test_update_protocol_address() {
    let (nft, _) = deploy_nft();
    
    let new_protocol_address = 'new_protocol'.try_into().unwrap();
    start_cheat_caller_address_global(owner());
    nft.update_peer_protocol_address(new_protocol_address);
}