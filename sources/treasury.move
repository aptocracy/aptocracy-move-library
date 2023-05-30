
module org_lib_addr::treasury {
  use aptos_framework::account::{Self, SignerCapability};
  use std::table_with_length::{Self, TableWithLength};
  use aptos_token::token::{Self};
  use aptos_framework::coin;
  use aptos_framework::aptos_coin::AptosCoin;
  use std::bcs;
  use std::vector;
  use std::event::{Self,EventHandle};
  use std::string::{Self, String};
  use aptos_framework::timestamp;
  use std::signer;
  use std::type_info::{Self, TypeInfo};


  struct Treasury<TreasuryMetadata: store> has key{
    authority: address,
    signer_capability: SignerCapability,
    treasury_index: u32,
    deposited_amount: u64,
    treasury_metadata: TreasuryMetadata,
    treasury_coin: TypeInfo,
    treasury_address:address
  }

  struct DepositRecords has key {
    deposits: TableWithLength<address, DepositRecord>,
  }

  struct DepositRecord has store {
    accumulated_amount: u64,
    last_deposited_at: u64,
    deposit_items: vector<DepositItem>,
    withdrawal_items: vector<WithdrawalItem>
  }

  struct DepositItem has store, drop {
    deposited_at: u64,
    accumulated_deposit_amount: u64
  }

  struct WithdrawalItem has store, drop {
    withdraw_at: u64,
    accumulated_withdraw_amount: u64
  }

  struct TreasuryEvents<TreasuryMetadata:store+drop> has key{
    deposit_event:EventHandle<DepositEvent<TreasuryMetadata>>,
    withdraw_event:EventHandle<WithdrawEvent<TreasuryMetadata>>,

  }

  struct DepositEvent<TreasuryMetadata> has store,drop{
    member_address:address,
    deposit_amount:u64,
    accumulated_deposit_record_amount: u64,
    treasury_metadata:TreasuryMetadata,
    treasury_address:address
  }


  struct WithdrawEvent<TreasuryMetadata> has store,drop{
    member_address:address,
    withdraw_amount:u64,
    accumulated_deposit_record_amount: u64,
    treasury_metadata:TreasuryMetadata,
    treasury_address:address
  }

  ///Deposit record does not exist
  const EDEPOSIT_RECORD_DOES_NOT_EXIST:u64 = 0;
  ///Insufficient amount
  const EINSUFICIENT_AMOUNT:u64 = 1;
  ///Amount must be higher then zero
  const EAMOUNT_CAN_NOT_BE_ZERO: u64 = 2;
  ///Treasury not initialized
  const ETREASURY_NOT_INITIALIZED: u64 = 3;
  ///Wrong currency
  const EWRONG_TREASURY_CURRENCY: u64 = 4;




  public fun create_treasury<TreasuryMetadata: store+drop, CoinType>(creator: &signer, authority_address: address, treasury_count: u32, treasury_metadata: TreasuryMetadata) {
    let seeds = bcs::to_bytes<String>(&string::utf8(b"treasury"));
    vector::append(&mut seeds, bcs::to_bytes<u32>(&(treasury_count + 1))); 
    let (res_signer, res_cap) = account::create_resource_account(creator, seeds);
    coin::register<AptosCoin>(&res_signer);
    token::opt_in_direct_transfer(&res_signer, true);



    move_to(
      &res_signer,
      Treasury<TreasuryMetadata> {
        authority: authority_address,
        signer_capability: res_cap,
        treasury_index: treasury_count + 1,
        deposited_amount: 0,
        treasury_metadata,
        treasury_coin: type_info::type_of<CoinType>(),
        treasury_address:signer::address_of(&res_signer)
      }
    );

    move_to(
      &res_signer,
      DepositRecords {
        deposits: table_with_length::new<address, DepositRecord>()
      }
    );

    move_to(&res_signer,TreasuryEvents{
      deposit_event:account::new_event_handle<DepositEvent<TreasuryMetadata>>(&res_signer),
      withdraw_event: account::new_event_handle<WithdrawEvent<TreasuryMetadata>>(&res_signer),
    });
  }

  public fun deposit<TreasuryMetadata: store+drop+copy, CoinType>(payer: &signer, deposit_amount: u64, treasury_address: address) acquires Treasury, DepositRecords,TreasuryEvents {
    assert!(exists<Treasury<TreasuryMetadata>>(treasury_address), ETREASURY_NOT_INITIALIZED);
    let treasury = borrow_global_mut<Treasury<TreasuryMetadata>>(treasury_address);

    //check if deposit amount is higher then zero
    assert!(deposit_amount >0, EAMOUNT_CAN_NOT_BE_ZERO);

    assert!(type_info::type_of<CoinType>() == treasury.treasury_coin, EWRONG_TREASURY_CURRENCY);

    coin::transfer<CoinType>(payer, treasury_address, deposit_amount);

    let deposit_table = borrow_global_mut<DepositRecords>(treasury_address);
    let deposit_time = timestamp::now_seconds();
    if(table_with_length::contains<address, DepositRecord>(&deposit_table.deposits, signer::address_of(payer))) {
      let deposit_record = table_with_length::borrow_mut<address, DepositRecord>(&mut deposit_table.deposits, signer::address_of(payer));
      deposit_record.accumulated_amount = deposit_record.accumulated_amount + deposit_amount;
      deposit_record.last_deposited_at = copy deposit_time;

    let last_index = vector::length<DepositItem>(&deposit_record.deposit_items) - 1;
    let last_deposit_item = vector::borrow<DepositItem>(&deposit_record.deposit_items, last_index);
      vector::push_back<DepositItem>(&mut deposit_record.deposit_items, DepositItem {
        deposited_at: copy deposit_time,
        accumulated_deposit_amount: last_deposit_item.accumulated_deposit_amount + deposit_amount
      });

    } else {
      let deposit_items: vector<DepositItem> = vector::empty<DepositItem>();
      let withdrawal_items: vector<WithdrawalItem> = vector::empty<WithdrawalItem>();

      vector::push_back<DepositItem>(&mut deposit_items, DepositItem {
        deposited_at: copy deposit_time,
        accumulated_deposit_amount: deposit_amount
      });
      table_with_length::add(&mut deposit_table.deposits, signer::address_of(payer), DepositRecord {
        accumulated_amount: deposit_amount,
        last_deposited_at: copy deposit_time,
        deposit_items,
        withdrawal_items
      })
    };
    treasury.deposited_amount = treasury.deposited_amount + deposit_amount;

    let treasury_events=borrow_global_mut<TreasuryEvents<TreasuryMetadata>>(treasury_address);

    let deposit_record=table_with_length::borrow<address,DepositRecord>(&deposit_table.deposits,signer::address_of(payer));

    event::emit_event<DepositEvent<TreasuryMetadata>>(&mut treasury_events.deposit_event,DepositEvent{
      member_address:signer::address_of(payer),
      deposit_amount: deposit_amount,
      accumulated_deposit_record_amount: deposit_record.accumulated_amount,
      treasury_address,
      treasury_metadata:treasury.treasury_metadata
    })

  }

  public fun withdraw<TreasuryMetadata: store + drop + copy, CoinType>(payer: &signer, withdraw_amount: u64, treasury_address: address) acquires Treasury, DepositRecords, TreasuryEvents {
    assert!(exists<Treasury<TreasuryMetadata>>(treasury_address), ETREASURY_NOT_INITIALIZED);
    let treasury = borrow_global_mut<Treasury<TreasuryMetadata>>(treasury_address);
    assert!(type_info::type_of<CoinType>() == treasury.treasury_coin, EWRONG_TREASURY_CURRENCY);
    assert!(withdraw_amount>0, EAMOUNT_CAN_NOT_BE_ZERO);

    let payer_address = signer::address_of(payer);

    let deposit_table = borrow_global_mut<DepositRecords>(treasury_address);
    assert!(table_with_length::contains<address, DepositRecord>(&deposit_table.deposits, payer_address), EDEPOSIT_RECORD_DOES_NOT_EXIST);
    let deposit_record = table_with_length::borrow_mut<address, DepositRecord>(&mut deposit_table.deposits, payer_address);
    assert!(deposit_record.accumulated_amount >= withdraw_amount, EINSUFICIENT_AMOUNT);
    let withdrawal_items_len = vector::length<WithdrawalItem>(&deposit_record.withdrawal_items);
    let withdraw_time = timestamp::now_seconds();
    if(withdrawal_items_len == 0) {
      vector::push_back<WithdrawalItem>(&mut deposit_record.withdrawal_items, WithdrawalItem {
        withdraw_at: withdraw_time,
        accumulated_withdraw_amount: withdraw_amount
      });
    }else {
      let last_withdraw_item_index = withdrawal_items_len - 1;
      let last_withdraw_item = vector::borrow<WithdrawalItem>(&deposit_record.withdrawal_items,last_withdraw_item_index);
      vector::push_back<WithdrawalItem>(&mut deposit_record.withdrawal_items, WithdrawalItem {
        withdraw_at: withdraw_time,
        accumulated_withdraw_amount: last_withdraw_item.accumulated_withdraw_amount + withdraw_amount
      });
    };
    deposit_record.accumulated_amount = deposit_record.accumulated_amount - withdraw_amount;
  
    let treasury_balance = coin::balance<CoinType>(treasury_address);
    assert!(treasury_balance >= withdraw_amount, EINSUFICIENT_AMOUNT);
    coin::transfer<CoinType>(&account::create_signer_with_capability(&treasury.signer_capability),payer_address, withdraw_amount);

    treasury.deposited_amount = treasury.deposited_amount - withdraw_amount;

    let treasury_events=borrow_global_mut<TreasuryEvents<TreasuryMetadata>>(treasury_address);

    event::emit_event<WithdrawEvent<TreasuryMetadata>>(&mut treasury_events.withdraw_event, WithdrawEvent {
      member_address:signer::address_of(payer),
      withdraw_amount:withdraw_amount,
      accumulated_deposit_record_amount: deposit_record.accumulated_amount,
      treasury_address,
      treasury_metadata:treasury.treasury_metadata
    });
    
  }

  public fun transfer_funds<TreasuryMetadata: store, CoinType>(transfer_amount: u64, transfer_address: address, treasury_address: address)  acquires Treasury{
    assert!(exists<Treasury<TreasuryMetadata>>(treasury_address), ETREASURY_NOT_INITIALIZED);
    let treasury = borrow_global_mut<Treasury<TreasuryMetadata>>(treasury_address);
    assert!(transfer_amount>0, EAMOUNT_CAN_NOT_BE_ZERO);

    let treasury_balance = coin::balance<CoinType>(treasury_address);
    assert!(treasury_balance >= transfer_amount, EINSUFICIENT_AMOUNT);
    coin::transfer<CoinType>(&account::create_signer_with_capability(&treasury.signer_capability), transfer_address, transfer_amount);


  }

  public fun get_basic_treasury_info<TreasuryMetadata: store + copy + drop>(treasury_address: address): (address, u32, TypeInfo, u64) acquires Treasury{
    let treasury = borrow_global<Treasury<TreasuryMetadata>>(treasury_address); 
    (
      treasury.authority,
      treasury.treasury_index,
      treasury.treasury_coin,
      treasury.deposited_amount,
    )
  }

  public fun get_treasury_metadata<TreasuryMetadata: store + copy + drop>(treasury_address: address): (TreasuryMetadata) acquires Treasury {
    let treasury = borrow_global<Treasury<TreasuryMetadata>>(treasury_address); 
    (
      treasury.treasury_metadata
    )
  }

  public fun get_accumulated_treasury_amount<TreasuryMetadata: store>(treasury_address: address): (u64) acquires Treasury {
    let treasury = borrow_global<Treasury<TreasuryMetadata>>(treasury_address); 
    (
      treasury.deposited_amount
    )
  }

  public fun get_deposited_amount_for_address<TreasuryMetadata: store>(treasury_address: address, depositer: address): (u64) acquires DepositRecords {
    assert!(exists<Treasury<TreasuryMetadata>>(treasury_address), ETREASURY_NOT_INITIALIZED);
    let deposit_records = borrow_global<DepositRecords>(treasury_address);
    if(!table_with_length::contains<address, DepositRecord>(&deposit_records.deposits, depositer)) {
      return 0
    };
    let deposit_record = table_with_length::borrow<address, DepositRecord>(&deposit_records.deposits, depositer);
    (
      deposit_record.accumulated_amount
    )

  }

  public fun get_deposited_amount_for_address_for_timestamp<TreasuryMetadata: store>(treasury_address: address, depositer: address, timestamp: u64): (u64) acquires DepositRecords {
    assert!(exists<Treasury<TreasuryMetadata>>(treasury_address), ETREASURY_NOT_INITIALIZED);
    let deposit_records = borrow_global<DepositRecords>(treasury_address);
    if(!table_with_length::contains<address, DepositRecord>(&deposit_records.deposits, depositer)) {
      return 0
    };
    let deposit_record = table_with_length::borrow<address, DepositRecord>(&deposit_records.deposits, depositer);

    let amount_balance: u64 = 0;

    //Deposited amount
    if(vector::length(&deposit_record.deposit_items) > 0) {
    let deposit_item_index = vector::length(&deposit_record.deposit_items) - 1;
    while(deposit_item_index >= 0) {
      let deposit_item = vector::borrow<DepositItem>(&deposit_record.deposit_items, deposit_item_index);
      if(deposit_item.deposited_at <= timestamp) {
        amount_balance = deposit_item.accumulated_deposit_amount;
        break
      };
      if(deposit_item_index == 0) break;
      deposit_item_index = deposit_item_index - 1;
    };
    };

    //Withdraw amount
    if(vector::length(&deposit_record.withdrawal_items) > 0) {
      let withdraw_item_index = vector::length(&deposit_record.withdrawal_items) - 1;
      while(withdraw_item_index >= 0) {
        let withdrawal_item = vector::borrow<WithdrawalItem>(&deposit_record.withdrawal_items, withdraw_item_index);
        if(withdrawal_item.withdraw_at <= timestamp) {
          amount_balance = amount_balance - withdrawal_item.accumulated_withdraw_amount;
          break
        };
        if(withdraw_item_index == 0) break;
        withdraw_item_index = withdraw_item_index - 1;
      };
    };

    (
      amount_balance
    )

  }

  public fun check_if_treasury_exists<TreasuryMetadata: store>(treasury_address: address): (bool) {
    exists<Treasury<TreasuryMetadata>>(treasury_address)
  }




  

  #[test_only]
  struct TestTreasuryMetadata has store, copy, drop {
    counter: u32
  }

  #[test_only]
  struct DifferentTestTreasuryMetadata has store, copy, drop {
    counter: u32
  }

  #[test_only]
  struct TestCoin {
  }

  #[test_only]
  public fun test_create_treasury(creator: &signer, authority_address: address): (address) acquires Treasury {
    create_treasury<TestTreasuryMetadata, AptosCoin>(creator, authority_address, 0, TestTreasuryMetadata{
      counter: 1
    });
    let seeds = bcs::to_bytes(&string::utf8(b"treasury"));
    vector::append(&mut seeds, bcs::to_bytes<u32>(&(1))); 
    let treasury_address = account::create_resource_address(&signer::address_of(creator), seeds);
    let treasury = borrow_global<Treasury<TestTreasuryMetadata>>(treasury_address);
    assert!(treasury.authority == authority_address, 0);
    assert!(treasury.treasury_index == 1, 0);
    assert!(treasury.deposited_amount == 0, 0);
    assert!(treasury.treasury_metadata.counter == 1, 0);
    treasury_address
  }

  #[test_only]
  public fun test_create_treasury_diff_metadata(creator: &signer, authority_address: address): (address) acquires Treasury {
    create_treasury<DifferentTestTreasuryMetadata, AptosCoin>(creator, authority_address, 0, DifferentTestTreasuryMetadata{
      counter: 1
    });
    let seeds = bcs::to_bytes(&string::utf8(b"treasury"));
    vector::append(&mut seeds, bcs::to_bytes<u32>(&(1)));  
    let treasury_address = account::create_resource_address(&signer::address_of(creator), seeds);
    let treasury = borrow_global<Treasury<DifferentTestTreasuryMetadata>>(treasury_address);
    assert!(treasury.authority == authority_address, 0);
    assert!(treasury.treasury_index == 1, 0);
    assert!(treasury.deposited_amount == 0, 0);
    assert!(treasury.treasury_metadata.counter == 1, 0);
    treasury_address
  }


  #[test_only]
  public fun aidrop_coins(framework: &signer, user_addr: address) {
    let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(framework);
    let coin = coin::mint<AptosCoin>(100, &mint);
    coin::deposit(user_addr, coin);
    coin::destroy_burn_cap(burn);
    coin::destroy_mint_cap(mint);
    let balance = coin::balance<AptosCoin>(user_addr);
    assert!(balance == 100, 0);
  }

  #[test(creator = @0x123, authority = @0x543, user = @0x323, framework = @0x1)]
  public fun treasury_flow(creator: signer, authority: signer, user: signer, framework: signer) acquires Treasury, DepositRecords,TreasuryEvents {
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);
    let user_addr = signer::address_of(&user);
    aptos_framework::aptos_account::create_account(copy user_addr);

    //Airdrop coins to user
    let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(&framework);
    let coin = coin::mint<AptosCoin>(100, &mint);
    coin::deposit(copy user_addr, coin);
    coin::destroy_burn_cap(burn);
    coin::destroy_mint_cap(mint);
    let balance = coin::balance<AptosCoin>(user_addr);
    assert!(balance == 100, 0);
    
    //Setup time - because we are using timestamp in deposit
    timestamp::set_time_has_started_for_testing(&framework);

    let treasury_address = test_create_treasury(&creator, authority_address);
    deposit<TestTreasuryMetadata, AptosCoin>(&user, 10, treasury_address);
    let treasury = borrow_global<Treasury<TestTreasuryMetadata>>(treasury_address);
    assert!(treasury.deposited_amount == 10, 0);
    assert!(treasury.treasury_index == 1, 0);
    assert!(treasury.authority == authority_address, 0);

    let deposit_table = borrow_global_mut<DepositRecords>(treasury_address);
    assert!(table_with_length::length<address, DepositRecord>(&deposit_table.deposits) == 1, 0);
    assert!(table_with_length::contains<address, DepositRecord>(&deposit_table.deposits, user_addr), 0);
    assert!(table_with_length::borrow<address, DepositRecord>(&deposit_table.deposits, user_addr).accumulated_amount == 10, 0);
    assert!(coin::balance<AptosCoin>(treasury_address) == 10, 0);
    
    withdraw<TestTreasuryMetadata, AptosCoin>(&user, 5, treasury_address);
    assert!(coin::balance<AptosCoin>(treasury_address) == 5, 0);
    let deposit_table_updated = borrow_global_mut<DepositRecords>(treasury_address);
    assert!(table_with_length::length<address, DepositRecord>(&deposit_table_updated.deposits) == 1, 0);
    assert!(table_with_length::contains<address, DepositRecord>(&deposit_table_updated.deposits, user_addr), 0);
    assert!(table_with_length::borrow<address, DepositRecord>(&deposit_table_updated.deposits, user_addr).accumulated_amount == 5, 0);

  }

  #[test(creator = @0x123, authority = @0x543, user = @0x323, framework = @0x1)]
  #[expected_failure(abort_code = ETREASURY_NOT_INITIALIZED)]
  public fun test_wrong_metadata(creator: signer, authority: signer, user: signer, framework: signer) acquires Treasury, DepositRecords,TreasuryEvents {
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);
    let user_addr = signer::address_of(&user);
    aptos_framework::aptos_account::create_account(copy user_addr);

    //Airdrop coins to user
    aidrop_coins(&framework, user_addr);
  
    //Setup time - because we are using timestamp in deposit
    timestamp::set_time_has_started_for_testing(&framework);

    let treasury_address = test_create_treasury(&creator, authority_address);
    deposit<DifferentTestTreasuryMetadata, AptosCoin>(&user, 10, treasury_address);
  }

  #[test(creator = @0x123, authority = @0x543, user = @0x323, framework = @0x1)]
  #[expected_failure(abort_code = EINSUFICIENT_AMOUNT)]
  public fun test_withdraw_higher_amount_then_treasury_balance(creator: signer, authority: signer, user: signer, framework: signer) acquires Treasury, DepositRecords,TreasuryEvents {
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);
    let user_addr = signer::address_of(&user);
    aptos_framework::aptos_account::create_account(copy user_addr);

    //Airdrop coins to user
    aidrop_coins(&framework, user_addr);
  
    //Setup time - because we are using timestamp in deposit
    timestamp::set_time_has_started_for_testing(&framework);

    let treasury_address = test_create_treasury(&creator, authority_address);
    deposit<TestTreasuryMetadata, AptosCoin>(&user, 10, treasury_address);
    withdraw<TestTreasuryMetadata, AptosCoin>(&user, 11, treasury_address);
  }

  #[test(creator = @0x123, authority = @0x543, user = @0x323, framework = @0x1)]
  #[expected_failure(abort_code = EWRONG_TREASURY_CURRENCY)]
  public fun test_deposit_different_currency(creator: signer, authority: signer, user: signer, framework: signer) acquires Treasury, DepositRecords ,TreasuryEvents{
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);
    let user_addr = signer::address_of(&user);
    aptos_framework::aptos_account::create_account(copy user_addr);

    //Airdrop coins to user
    aidrop_coins(&framework, user_addr);
  
    //Setup time - because we are using timestamp in deposit
    timestamp::set_time_has_started_for_testing(&framework);

    let treasury_address = test_create_treasury(&creator, authority_address);
    deposit<TestTreasuryMetadata, TestCoin>(&user, 10, treasury_address);
  }

  #[test(creator = @0x123, authority = @0x543, user = @0x323, framework = @0x1)]
  #[expected_failure(abort_code = EWRONG_TREASURY_CURRENCY)]
  public fun test_withdraw_different_currency(creator: signer, authority: signer, user: signer, framework: signer) acquires Treasury, DepositRecords ,TreasuryEvents{
    //Prepare accounts for test
    account::create_account_for_test(signer::address_of(&creator));
    let authority_address = signer::address_of(&authority);
    account::create_account_for_test(authority_address);
    let user_addr = signer::address_of(&user);
    aptos_framework::aptos_account::create_account(copy user_addr);

    //Airdrop coins to user
    aidrop_coins(&framework, user_addr);
  
    //Setup time - because we are using timestamp in deposit
    timestamp::set_time_has_started_for_testing(&framework);

    let treasury_address = test_create_treasury(&creator, authority_address);
    deposit<TestTreasuryMetadata, AptosCoin>(&user, 10, treasury_address);
    withdraw<TestTreasuryMetadata, TestCoin>(&user, 5, treasury_address);
  }


}