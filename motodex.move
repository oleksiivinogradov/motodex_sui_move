module motodex_sui_contracts::core {
    use std::option;
    use std::option::Option;
    use std::string;
    use std::string::{String};
    use std::vector;
    use sui::clock;
    use sui::clock::Clock;
    use sui::coin;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url;
    use sui::url::Url;
    use sui::vec_map;
    use sui::vec_map::{VecMap, get};

    use sui::balance;
    use sui::balance::Balance;
    use sui::coin::{Coin};

    // Part 2: Struct definitions
    // errors
    const INVALID_SIGNER: u64 = 0;
    const PRICE_ZERO: u64 = 1;
    const E_WRONG_COLLECTION: u64 = 2;
    const E_WRONG_NFT_TYPE: u64 = 3;
    const E_WRONG_TRACK_PERCENT: u64 = 4;
    const E_INVALID_OWNER: u64 = 5;
    const E_INVALID_HEALTH: u64 = 6;
    const E_MOTO_NOT_FOUND: u64 = 7;
    const E_MINIMAL_BID: u64 = 8;
    const E_NO_FEES_GS: u64 = 9;
    const E_WRONG_PLATFORM_SUM_GS: u64 = 10;
    const E_EPOCH_MINIMAL_INTERVALS: u64 = 11;
    const E_EPOCH_MINIMAL_GS_DURATION: u64 = 12;
    const E_EPOCH_GS_PAYMENTS_MORE_THAN_AVALIABLE: u64 = 13;
    const E_EPOCH_NO_PAYMENS: u64 = 14;
    const E_NO_COLLECTED_FEES: u64 = 15;
    const ENotOneTimeWitness: u64 = 16;
    const ENotEnough: u64 = 17;
    const EHealthAreFull: u64 = 18;
    const E_SYNC_INVALID_RECEIVER: u64 = 19;

    // names

    const WINNER_RATE: u64 = 6000;
    const BID_WINNER_RATE: u64 = 7000;
    const TEN_PERCENT_RATE: u64 = 1000;
    const HUNDED_PERCENT_RATE: u64 = 10000;
    const THIRTY_PERCENT_RATE: u64 = 3000;
    const TWENTY_PERCENT_RATE: u64 = 2000;
    const FOURTY_PERCENT_RATE: u64 = 4000;

    // receiver types:
    const TRACK:u8 = 0;
    const MOTO:u8 = 1;
    const BIDDER:u8 = 2;
    const PLATFORM:u8 = 3;

    // moto:
    const RED_BULLER:u8 = 0;
    const ZEBRA_GRRR:u8 = 1;
    const ROBO_HORSE:u8 = 2;
    const METAL_EYES:u8 = 3;
    const BROWN_KILLER:u8 = 4;
    const CRAZY_LINE:u8 = 5;
    const MAGIC_BOX:u8 = 6;
    const HEALTH_PILL_5:u8 = 7;
    const HEALTH_PILL_10:u8 = 8;
    const HEALTH_PILL_30:u8 = 9;
    const HEALTH_PILL_50:u8 = 10;
    // tracks:
    const TRACK_LONDON:u8 = 100;
    const TRACK_DUBAI:u8 = 101;
    const TRACK_ABU_DHABI:u8 = 102;
    const TRACK_BEIJIN:u8 = 103;
    const TRACK_MOSCOW:u8 = 104;
    const TRACK_MELBURN:u8 = 105;
    const TRACK_PETERBURG:u8 = 106;
    const TRACK_TAIPEI:u8 = 107;
    const TRACK_PISA:u8 = 108;
    const TRACK_ISLAMABAD:u8 = 109;

    public struct Nfts has key, store {
        id: UID,
        price_usd: VecMap<u8, u64>,
        name: VecMap<u8, String>,
        description: VecMap<u8, String>,
        uri: VecMap<u8, std::ascii::String>,
        percent_grow: VecMap<u8, u64>
    }

    public struct OwnerCap has key { id: UID }

    /// Kiosk extension witness.
    public struct KExt has drop {}


    public struct Motodex has key {
        id: UID,
        /// Mapping from token to owner.
        token_owner: VecMap<u256, address>,
        // /// Contract owner account id
        owners: vector<address>,
        // /// Game server
        game_servers: vector<address>,
        // /// Ratio in basis points for minimal fee taken where 10000 = 100% (1 MAIN COIN)
        minimal_fee: u64,
        // /// Epoch min duration in microseconds
        epoch_minimal_interval: u64,
        // /// Epoch min duration in microseconds
        min_game_session_duration: u64,
        // /// Max required num of motos per one game session
        max_moto_per_session: u64,
        /// `Track`, `Moto`, `HealthPill` for given token id
        token_types: VecMap<address, u8>,
        /// Pairs represented health for given token id
        token_health: VecMap<address, u64>,
        /// Pairs represented percent per track for givem track token id
        percent_for_track: VecMap<address, u64>,
        /// MainCoin Price in USD
        price_main_coin_usd: u64,
        /// one MainCoin with decimals
        one_main_coin: u64,
        /// &track_nft, &game_session
        game_sessions: VecMap<address, GameSession>,
        /// Converted
        game_bids: VecMap<address, TrackGameBid>,
        /// Converted
        // previous_owners: SmartTable<u256, TokenInfo>,
        // /// Converted
        nft_owners: VecMap<address, TokenInfo>,
        // tracks_owners: SmartTable<u256, TokenInfo>,

        /// in microseconds
        latest_epoch_update: u64,
        /// counter
        counter: u256,
        total_supply: u256,
        nfts: Nfts,
        balance: Balance<SUI>,
        // kiosk: Kiosk,
        // kiosk_owner_cap: KioskOwnerCap
    }

    public struct TokenInfo has store, drop, copy {
        // id: UID,
        owner_id: address,
        token_type: u8,
        active_session: Option<address>, // track address
        collected_fee: u64,
    }

    public struct GameBid has store, copy, drop {
        // id: UID,
        amount: u64,
        moto: address,
        timestamp: u64,
        bidder: address,
    }

    public struct TrackGameBid has store, copy, drop {
        // id: UID,
        game_bids: vector<GameBid>,
    }

    public struct GameSessionMoto has store, copy, drop {
        // id: UID,
        moto_owner: address,
        moto_nft: address,
        last_track_time_result: u64,
    }

    public struct EpochPayment has copy, drop, store {
        track_token: address,
        moto_token: Option<address>,
        receiver_type: u8,
        amount: u64,
        receiver_id: address,
    }

    public struct GameSession has store, drop, copy {
        // id: UID,
        /// Time when this session was created
        init_time: u64,
        /// Cloned track token id for ping session
        track_token: address,
        moto: vector<GameSessionMoto>,
        latest_update_time: u64,
        latest_track_time_result: u64,
        attempts: u64,
        game_bids_sum: u64,
        game_fees_sum: u64,
        //stored current winner
        current_winner_moto: Option<GameSessionMoto>,
        epoch_payment: vector<EpochPayment>,
        max_moto_per_session: u64,
    }

    public struct FinalGameSessionView has copy, drop {
        finished_at: u64,
        /// Cloned track token id for ping session
        track_token: address,
        winner_account: address,
        winner_nft: address,
        winner_result: u64,
        total_attempts: u64,
        total_balance: u64,
        payments: vector<EpochPayment>
    }

    public struct MotodexNFT has key {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Description of the token
        description: string::String,
        /// URL for the token
        url: Url,
        // TODO: allow custom attributes
        owner: address,

        type_final: u8,
        health: u64,
        price: u64


    }

    /// OTW is a struct with only `drop` and is named
    /// after the module - but uppercased. See "One Time
    /// Witness" page for more details.
    // struct MOTODEX has drop {}

    // EVENTS functions
    public struct MintEvent has copy, drop {
        from: address,
        nft: address,
        type_nft: u8,
        timestamp: u64,
    }

    public struct PurchaseEvent has copy, drop {
        from: address,
        nft: address,
        type_nft: u8,
        timestamp: u64,
        value: u64
    }
    public struct AddNFTEvent has copy, drop {
        from: address,
        to: address,
        nft: address,
        type_nft: u8,
        timestamp: u64,
        value: u64
    }
    public struct ReturnNFTEvent has copy, drop {
        from: address,
        nft: address,
        type_nft: u8,
        timestamp: u64
    }
    public struct AddHealthMoney has copy, drop {
        from: address,
        nft: address,
        type_nft: u8,
        timestamp: u64,
        value: u64
    }
    public struct AddHealthNFT has copy, drop {
        from: address,
        nft: address,
        type_nft: u8,
        timestamp: u64,
        health_pill: address
    }
    public struct CreateOrUpdateGameSession has copy, drop {
        from: address,
        track: address,
        moto: address,
        timestamp: u64,
        last_track_time_result: u64,
    }
    public struct AddBid has copy, drop {
        bidder: address,
        track: address,
        moto: address,
        timestamp: u64,
        amount: u64
    }
    public struct RemoveBidNFTEvent has copy, drop {
        bidder: address,
        track: address,
        moto: address,
        timestamp: u64,
        amount: u64
    }

    public struct AfterSyncSession has copy, drop {
        final_game_session_view: FinalGameSessionView
    }

    public struct UpdateCounterEvent has copy, drop {
        from: address,
        timestamp: u64
    }




    // INTERNAL functions
    fun internal_get_price_for_type(type_nft: u8, motodex: &Motodex): u64 {
        let price_for_type_usd = internal_get_price_for_type_usd(type_nft, motodex);
        let price_main_coin = price_for_type_usd * motodex.one_main_coin / motodex.price_main_coin_usd;
        return price_main_coin
    }
    fun internal_get_price_for_type_usd(type_nft: u8, motodex: &Motodex): u64  {
        let p =  motodex.nfts.price_usd;
        *get(&p, &type_nft)
    }
    fun internal_get_type_for(object: address, motodex: &Motodex): u8  {
        *get(&motodex.token_types,
            &object)
    }
    fun internal_get_health_for(object: address, motodex: &Motodex): u64  {
        *get(&motodex.token_health,
            &object)
    }
    fun internal_mint_nft(receiver: address, type_nft: u8, motodex: &mut Motodex, clock: &Clock, ctx: &mut TxContext):address {
        // mint nft
        let mut type_final = type_nft;
        if (type_nft == MAGIC_BOX) {
            type_final = 3;//randomness::u8_range(0, 5);
        };
        // let collection_name = string::utf8(COLLECTION_NAME);
        let token_name_main = *get(
            &motodex.nfts.name,
            &type_final
        );
        // let t1= clock::timestamp_ms(clock);
        // let token_name = format(&b"{} {} {}", token_name_main, motodex.total_supply ,t1);
        let token_uri = *get(
            &motodex.nfts.uri,
            &type_final
        );
        let description = *get(
            &motodex.nfts.description,
            &type_final
        );
        let price = internal_get_price_for_type(type_final, motodex);

        let new_token = MotodexNFT {
            id: object::new(ctx),
            name: token_name_main,
            description,
            url: url::new_unsafe(token_uri),
            owner: receiver,
            type_final,
            health: price,
            price
        };
        vec_map::insert(&mut motodex.token_types ,object::id_address(&new_token), type_final);
        vec_map::insert(&mut motodex.token_health, object::id_address(&new_token), price);
        if (type_final > 99) {
            vec_map::insert(&mut motodex.percent_for_track, object::id_address(&new_token), THIRTY_PERCENT_RATE);
        };
        motodex.total_supply = motodex.total_supply + 1;

        let (type_final, mut final_price) = vec_map::remove(
            &mut motodex.nfts.price_usd,
            &type_final
        );

        let percent_grow = *vec_map::get_mut(
            &mut motodex.nfts.percent_grow,
            &type_final
        );
        final_price = final_price * (100 + percent_grow) / 100;
        vec_map::insert(&mut motodex.nfts.price_usd, type_final, final_price);
        let address = object::id_address(&new_token);
        transfer::transfer(new_token, receiver);
        event::emit(PurchaseEvent {
            from: tx_context::sender(ctx),
            nft: address,
            type_nft,
            timestamp: clock::timestamp_ms(clock),
            value: price
        });
        address
    }

    fun internal_purchase(coin:Coin<SUI>, type_nft: u8, motodex: &mut Motodex, clock: &Clock, ctx: &mut TxContext):address  {
        let sender = tx_context::sender(ctx);
        let price = internal_get_price_for_type(type_nft, motodex);

        assert!(price > 0, PRICE_ZERO);
        assert!(coin::value(&coin) >= price, ENotEnough);

        let balance = coin.into_balance();

        motodex.balance.join(balance);
        // let coin_balance = coin::into_balance(coin);
        // let paid = balance::split(&mut coin_balance, price);
        //
        // // Put the coin to the Motodex's balance
        // balance::join(&mut motodex.balance, paid);

        let new_token = internal_mint_nft(sender, type_nft, motodex, clock, ctx);

        // Emit the event just defined.
        event::emit(PurchaseEvent {
            from: sender,
            nft: new_token,
            type_nft,
            timestamp: clock::timestamp_ms(clock),
            value: price
        });
        new_token
    }

    fun internal_init_module(ctx: &mut TxContext) {
        transfer::transfer(OwnerCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        // Create an object that will hold the collection
        // assert!(types::is_one_time_witness(&otw), ENotOneTimeWitness);

        // let description = string::utf8(b"Motodex collection");
        // let collection_uri = string::utf8(b"https://openbisea.mypinata.cloud/ipfs/QmdCinoHCA2zfgkWKMrMZcdPyX7nsU8oPr5WVRWxMovbYC?_gl=1*1kxadn4*_ga*MjAzNTMwOTAyMi4xNzA0ODc5NTkz*_ga_5RMPXG14TE*MTcwNDg3OTU5Mi4xLjEuMTcwNDg3OTY2NS42MC4wLjA.");

        let mut list = vector::empty<address>();
        let account_addr = tx_context::sender(ctx);
        vector::push_back(&mut list, account_addr);

        let one_main_coin = 100_000_000;


        let mut price_usd = vec_map::empty<u8, u64>();
        vec_map::insert(&mut price_usd, RED_BULLER, one_main_coin * 1);
        vec_map::insert(&mut price_usd, ZEBRA_GRRR, one_main_coin * 6);
        vec_map::insert(&mut price_usd, ROBO_HORSE, one_main_coin * 7);
        vec_map::insert(&mut price_usd, METAL_EYES, one_main_coin * 8);
        vec_map::insert(&mut price_usd, BROWN_KILLER, one_main_coin * 9);
        vec_map::insert(&mut price_usd, CRAZY_LINE, one_main_coin * 10);
        vec_map::insert(&mut price_usd, MAGIC_BOX, one_main_coin * 7);
        vec_map::insert(&mut price_usd, HEALTH_PILL_5, one_main_coin * 1);
        vec_map::insert(&mut price_usd, HEALTH_PILL_10, one_main_coin * 3);
        vec_map::insert(&mut price_usd, HEALTH_PILL_30, one_main_coin * 5);
        vec_map::insert(&mut price_usd, HEALTH_PILL_50, one_main_coin * 10);
        vec_map::insert(&mut price_usd, TRACK_LONDON, one_main_coin * 1);
        vec_map::insert(&mut price_usd, TRACK_DUBAI, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_ABU_DHABI, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_BEIJIN, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_MOSCOW, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_MELBURN, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_PETERBURG, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_TAIPEI, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_PISA, one_main_coin * 50);
        vec_map::insert(&mut price_usd, TRACK_ISLAMABAD, one_main_coin * 50);

        let mut name = vec_map::empty<u8, String>();
        vec_map::insert(&mut name, RED_BULLER, string::utf8(b"Red Bulller"));
        vec_map::insert(&mut name, ZEBRA_GRRR, string::utf8(b"Zebra Grrrr"));
        vec_map::insert(&mut name, ROBO_HORSE, string::utf8(b"Robo Horse"));
        vec_map::insert(&mut name, METAL_EYES, string::utf8(b"Metal Eyes"));
        vec_map::insert(&mut name, BROWN_KILLER, string::utf8(b"Brown Killer"));
        vec_map::insert(&mut name, CRAZY_LINE, string::utf8(b"Crazy Line"));
        vec_map::insert(&mut name, MAGIC_BOX, string::utf8(b"Magic box"));
        vec_map::insert(&mut name, HEALTH_PILL_5, string::utf8(b"Health Capsule 5"));
        vec_map::insert(&mut name, HEALTH_PILL_10, string::utf8(b"Health Capsule 10"));
        vec_map::insert(&mut name, HEALTH_PILL_30, string::utf8(b"Health Capsule 30"));
        vec_map::insert(&mut name, HEALTH_PILL_50, string::utf8(b"Health Capsule 50"));
        vec_map::insert(&mut name, TRACK_LONDON, string::utf8(b"London"));
        vec_map::insert(&mut name, TRACK_DUBAI, string::utf8(b"Dubai"));
        vec_map::insert(&mut name, TRACK_ABU_DHABI, string::utf8(b"Abu Dhabi"));
        vec_map::insert(&mut name, TRACK_BEIJIN, string::utf8(b"Beijing"));
        vec_map::insert(&mut name, TRACK_MOSCOW, string::utf8(b"Moscow"));
        vec_map::insert(&mut name, TRACK_MELBURN, string::utf8(b"Melbourne"));
        vec_map::insert(&mut name, TRACK_PETERBURG, string::utf8(b"Petersburg"));
        vec_map::insert(&mut name, TRACK_TAIPEI, string::utf8(b"Taipei"));
        vec_map::insert(&mut name, TRACK_PISA, string::utf8(b"Pisa"));
        vec_map::insert(&mut name, TRACK_ISLAMABAD, string::utf8(b"Islamabad"));

        let mut description = vec_map::empty<u8, String>();
        vec_map::insert(&mut description, RED_BULLER, string::utf8(b"Introducing the adrenaline-fueled world of Red Buller motoDEX, where speed, skill, and strategy meet in a high-stakes battle for victory. And now, you can own a piece of the action with our exclusive NFT game assets featuring the highly coveted health box five value.\nThese assets are more than just pixels on a screen. They represent the ultimate in gaming prowess, a testament to your ability to dominate the competition and stay one step ahead of the pack. And with the health box five value, you'll have the edge you need to push yourself to the limit and come out on top."));
        vec_map::insert(&mut description, ZEBRA_GRRR, string::utf8(b"Get ready to unleash your wild side with Zebra Grrrr, the hottest new NFT game assets on the market. These assets are not for the faint of heart - they represent the ultimate in speed, strength, and agility, all wrapped up in a fierce and fearless design.\nAnd with the highly coveted health box value of 7, these assets are the ultimate power-up for any serious gamer. You'll be able to outlast your opponents, shrug off attacks, and charge ahead with unbridled energy and determination."));
        vec_map::insert(&mut description, ROBO_HORSE, string::utf8(b"Step into the future of gaming with Robo Horse, the ultimate NFT game assets that combine advanced technology with sleek and powerful design. These assets represent the pinnacle of gaming performance, delivering lightning-fast speed, unmatched strength, and unparalleled endurance.\nAnd with the highly sought-after health box value of 10, these assets are virtually indestructible. You'll be able to weather any storm, outlast any challenge, and emerge victorious time and time again."));
        vec_map::insert(&mut description, METAL_EYES, string::utf8(b"Get ready to take on the competition with Metal Eyes, the ultimate NFT game assets that are as fierce as they are formidable. These assets represent the ultimate combination of strength, speed, and style, with a sleek metallic design that's sure to catch the eye of any gaming enthusiast.\nAnd with the highly coveted health box value of 20, these assets are virtually indestructible. You'll be able to withstand even the toughest challenges, outlast your opponents, and emerge victorious time and time again."));
        vec_map::insert(&mut description, BROWN_KILLER, string::utf8(b"Step into the world of Brown Killer, the ultimate NFT game assets that embody the spirit of strength, speed, and power. With their sleek design and unbeatable performance, these assets are the ultimate tool for any serious gamer looking to dominate the competition.\nAnd with the highly coveted health box value of 30, Brown Killer is virtually unstoppable. You'll be able to shrug off attacks, outlast your opponents, and emerge victorious time and time again."));
        vec_map::insert(&mut description, CRAZY_LINE, string::utf8(b"Are you ready to go beyond the limits with Crazy Line, the ultimate NFT game assets that defy convention and push the boundaries of gaming excellence? With their bold and dynamic design, these assets represent the ultimate in speed, agility, and strategic thinking.\nAnd with the highly coveted health box value of 50, Crazy Line is virtually indestructible. You'll be able to outlast any challenge, overcome any obstacle, and emerge victorious time and time again."));
        vec_map::insert(&mut description, MAGIC_BOX, string::utf8(b"Unlock the mystery of gaming with Magic Box, the ultimate NFT game assets that are shrouded in secrecy and full of surprises. With their randomly selected character design, these assets are the ultimate test of your gaming skills and strategic thinking.\nAnd with the potential to receive any of the highly coveted characters, Magic Box is truly a game-changer. You'll have the opportunity to explore different gaming styles and strategies, unlocking new levels of performance and creativity."));
        vec_map::insert(&mut description, HEALTH_PILL_5, string::utf8(b"Used to replenish the lives of the player. Capsules add 5,10,30,50 lives. The starting price of items is 0.5 /1/3/5 dollars, respectively. The price of items increases by 0.1% after each new sale."));
        vec_map::insert(&mut description, HEALTH_PILL_10, string::utf8(b"Used to replenish the lives of the player. Capsules add 5,10,30,50 lives. The starting price of items is 0.5 /1/3/5 dollars, respectively. The price of items increases by 0.1% after each new sale."));
        vec_map::insert(&mut description, HEALTH_PILL_30, string::utf8(b"Used to replenish the lives of the player. Capsules add 5,10,30,50 lives. The starting price of items is 0.5 /1/3/5 dollars, respectively. The price of items increases by 0.1% after each new sale."));
        vec_map::insert(&mut description, HEALTH_PILL_50, string::utf8(b"Used to replenish the lives of the player. Capsules add 5,10,30,50 lives. The starting price of items is 0.5 /1/3/5 dollars, respectively. The price of items increases by 0.1% after each new sale."));
        vec_map::insert(&mut description, TRACK_LONDON, string::utf8(b"A ride through the expanses of the capital of Great Britain reveals to the racers all the beauty of the Palace of Westminster and its main attraction - the Big Ben clock tower."));
        vec_map::insert(&mut description, TRACK_DUBAI, string::utf8(b"The Dubai track is located in the heart of the elite metropolis of the UAE. Landscape with luxurious skyscrapers and the tourist gem of the city - the hotel Parus."));
        vec_map::insert(&mut description, TRACK_ABU_DHABI, string::utf8(b"The Abu Dhabi Circuit takes racers into a world of sandy desert and urban oasis in the form of buildings made of glass and concrete."));
        vec_map::insert(&mut description, TRACK_BEIJIN, string::utf8(b"Endless green fields and the world-famous Great Wall of China are the scenery enjoyed by racers on the Beijing circuit."));
        vec_map::insert(&mut description, TRACK_MOSCOW, string::utf8(b"The bewitching Kremlin, the famous clock tower and the Patriarch's Ponds make a textbook landscape that opens up to riders on the Moscow track."));
        vec_map::insert(&mut description, TRACK_MELBURN, string::utf8(b"The Melbourne circuit is a mix of all the most striking sights of Australia - its delightful business centers and the famous Sydney Opera House."));
        vec_map::insert(&mut description, TRACK_PETERBURG, string::utf8(b"Petersburg highway is a track with a view of the urban glass forest of multi-storey business centers of the St. Petersburg Plaza business complex."));
        vec_map::insert(&mut description, TRACK_TAIPEI, string::utf8(b"Landscape on the highway Taipei is a classic modern Asian city with luxurious multi-storey brick buildings and a famous skyscraper - in our case, Taipei."));
        vec_map::insert(&mut description, TRACK_PISA, string::utf8(b"The track in the city of Pisa is a unique Italian flavor and one of the most famous sights of Italy - the Leaning Tower of Pisa."));
        vec_map::insert(&mut description, TRACK_ISLAMABAD, string::utf8(b"The race track in the capital of Pakistan is a virtual tour of the picturesque streets of the city and acquaintance with the luxurious red mosque."));

        let mut uri = vec_map::empty<u8, std::ascii::String>();
        vec_map::insert(&mut uri, RED_BULLER, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/red%20buller.gif"));
        vec_map::insert(&mut uri, ZEBRA_GRRR, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/zebra%20grr.gif"));
        vec_map::insert(&mut uri, ROBO_HORSE, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/robo%20horse.gif"));
        vec_map::insert(&mut uri, METAL_EYES, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/metal%20eyes.gif"));
        vec_map::insert(&mut uri, BROWN_KILLER, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/brown%20killer.gif"));
        vec_map::insert(&mut uri, CRAZY_LINE, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/crazy%20line.gif"));
        vec_map::insert(&mut uri, MAGIC_BOX, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/magic%20box.gif"));
        vec_map::insert(&mut uri, HEALTH_PILL_5, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/health5.gif"));
        vec_map::insert(&mut uri, HEALTH_PILL_10, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/health10.gif"));
        vec_map::insert(&mut uri, HEALTH_PILL_30, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/health30.gif"));
        vec_map::insert(&mut uri, HEALTH_PILL_50, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/health50.gif"));
        vec_map::insert(&mut uri, TRACK_LONDON, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/lonfon_optimized.gif"));
        vec_map::insert(&mut uri, TRACK_DUBAI, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/dubai.gif"));
        vec_map::insert(&mut uri, TRACK_ABU_DHABI, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/abu%20dhabi.gif"));
        vec_map::insert(&mut uri, TRACK_BEIJIN, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/beijin.gif"));
        vec_map::insert(&mut uri, TRACK_MOSCOW, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/moscow.gif"));
        vec_map::insert(&mut uri, TRACK_MELBURN, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/melburn_optimized.gif"));
        vec_map::insert(&mut uri, TRACK_PETERBURG, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/peterburg.gif"));
        vec_map::insert(&mut uri, TRACK_TAIPEI, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/taipei_optimized.gif"));
        vec_map::insert(&mut uri, TRACK_PISA, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/pisa.gif"));
        vec_map::insert(&mut uri, TRACK_ISLAMABAD, std::ascii::string(b"https://openbisea.mypinata.cloud/ipfs/QmQWJNzPhyMSpaE6Wwaxry46AuAG1bpWrQoG3PpotLbjzY/islamabad.gif"));

        let mut percent_grow = vec_map::empty<u8, u64>();
        vec_map::insert(&mut percent_grow, RED_BULLER, 1);
        vec_map::insert(&mut percent_grow, ZEBRA_GRRR, 1);
        vec_map::insert(&mut percent_grow, ROBO_HORSE, 1);
        vec_map::insert(&mut percent_grow, METAL_EYES, 1);
        vec_map::insert(&mut percent_grow, BROWN_KILLER, 1);
        vec_map::insert(&mut percent_grow, CRAZY_LINE, 1);
        vec_map::insert(&mut percent_grow, MAGIC_BOX, 1);
        vec_map::insert(&mut percent_grow, HEALTH_PILL_5, 1);
        vec_map::insert(&mut percent_grow, HEALTH_PILL_10, 1);
        vec_map::insert(&mut percent_grow, HEALTH_PILL_30, 1);
        vec_map::insert(&mut percent_grow, HEALTH_PILL_50, 1);
        vec_map::insert(&mut percent_grow, TRACK_LONDON, 10);
        vec_map::insert(&mut percent_grow, TRACK_DUBAI, 10);
        vec_map::insert(&mut percent_grow, TRACK_ABU_DHABI, 10);
        vec_map::insert(&mut percent_grow, TRACK_BEIJIN, 10);
        vec_map::insert(&mut percent_grow, TRACK_MOSCOW, 10);
        vec_map::insert(&mut percent_grow, TRACK_MELBURN, 10);
        vec_map::insert(&mut percent_grow, TRACK_PETERBURG, 10);
        vec_map::insert(&mut percent_grow, TRACK_TAIPEI, 10);
        vec_map::insert(&mut percent_grow, TRACK_PISA, 10);
        vec_map::insert(&mut percent_grow, TRACK_ISLAMABAD, 10);

        let n = Nfts {
                id: object::new(ctx),
                price_usd,
                name,
                description,
                uri,
                percent_grow
            };
        // let (kiosk, kiosk_owner_cap) = kiosk::new(ctx);
        // kext::add(KExt {}, &mut kiosk, &kiosk_owner_cap, 0, ctx); // may not lock, may not place

        let m = Motodex {
            id: object::new(ctx),
            token_owner : vec_map::empty(),
            owners : list ,
            game_servers : list,
            minimal_fee : 1_000 ,
            epoch_minimal_interval : 1,
            min_game_session_duration : 1,
            max_moto_per_session : 1_000,
            token_types:  vec_map::empty(),
            token_health:  vec_map::empty(),
            percent_for_track:  vec_map::empty(),
            price_main_coin_usd: one_main_coin * 7, //7$ 1 APT
            one_main_coin,
            game_sessions:  vec_map::empty(),
            game_bids: vec_map::empty(),
            latest_epoch_update: 0,
            counter: 0,
            nft_owners: vec_map::empty(),
            total_supply: 0,
            nfts: n,
            balance: balance::zero<SUI>(),
            // kiosk,
            // kiosk_owner_cap
        };

        transfer::share_object(m);

    }

    fun internal_ping_session(gs_old: GameSession, motodex: &Motodex):GameSession {
        let mut gs = GameSession {
            // id: object::new(ctx),
            init_time: gs_old.init_time,
            track_token: gs_old.track_token,
            moto: gs_old.moto,
            latest_update_time: gs_old.latest_update_time,
            latest_track_time_result: gs_old.latest_track_time_result,
            attempts: gs_old.attempts,
            game_bids_sum: gs_old.game_bids_sum,
            game_fees_sum: gs_old.game_fees_sum,
            // stored current winner
            current_winner_moto: gs_old.current_winner_moto,
            epoch_payment: gs_old.epoch_payment,
            max_moto_per_session: gs_old.max_moto_per_session,
        };

        if (!option::is_none(&gs.current_winner_moto)) {
            let game_session_bids_sum = gs.game_bids_sum;
            let game_session_fees_sum = gs.game_fees_sum;
            assert!(
                game_session_fees_sum > 0,
                E_NO_FEES_GS
            );
            let ratio_for_track = get(&motodex.percent_for_track, &gs.track_token);
            let track_token_info = get(&motodex.nft_owners, &gs.track_token);
            let winner_moto_payment_amount = game_session_fees_sum / WINNER_RATE * HUNDED_PERCENT_RATE;// a * b / c
            let track_owner_payment_amount = game_session_fees_sum * (*ratio_for_track) / HUNDED_PERCENT_RATE;// a * b / c
            let platform_payment_amount = game_session_fees_sum - winner_moto_payment_amount - track_owner_payment_amount;
            assert!(
                platform_payment_amount > 0,
                E_WRONG_PLATFORM_SUM_GS
            );
            let moto_winner = option::borrow(&gs.current_winner_moto);

            let mut winner_moto_payment = EpochPayment {
                track_token: gs.track_token,
                moto_token: option::some(moto_winner.moto_nft),
                receiver_type: MOTO,
                amount: winner_moto_payment_amount,
                receiver_id: moto_winner.moto_owner,
            };

            let mut track_owner_payment = EpochPayment {
                track_token: gs.track_token,
                moto_token: option::none(),
                receiver_type: TRACK,
                amount: track_owner_payment_amount,
                receiver_id: track_token_info.owner_id,
            };

            let owner = vector::borrow(&motodex.owners, 0);
            let mut platform_payment = EpochPayment {
                track_token: gs.track_token,
                moto_token: option::none(),
                receiver_type: PLATFORM,
                amount: platform_payment_amount,
                receiver_id: *owner,
            };

            if (game_session_bids_sum > 0) {
                // total bids sum * 70%
                let amount_to_pay_bidders = game_session_bids_sum * BID_WINNER_RATE / HUNDED_PERCENT_RATE;// a * b / c
                // total bids sum * 10%
                let amount_to_pay_others = game_session_bids_sum * TEN_PERCENT_RATE / HUNDED_PERCENT_RATE;// a * b / c
                track_owner_payment.amount = track_owner_payment.amount + amount_to_pay_others;
                winner_moto_payment.amount = winner_moto_payment.amount + amount_to_pay_others;
                platform_payment.amount = platform_payment.amount + amount_to_pay_others;

                let track_game_bids =  get(&motodex.game_bids, &gs.track_token);
                let mut game_success_bids = vector::empty<GameBid>();
                let mut game_success_bids_sum:u64 = 0;

                let mut index = vector::length(&track_game_bids.game_bids);

                while (index > 0) {
                    index = index - 1;
                    let bid = vector::borrow(&track_game_bids.game_bids, index);
                    if (bid.moto == moto_winner.moto_nft) {
                        vector::push_back(&mut game_success_bids, *bid
                        //     GameBid {
                        //     // id: object::new(ctx),
                        //     amount: bid.amount,
                        //     moto: bid.moto,
                        //     timestamp: bid.timestamp,
                        //     bidder: bid.bidder,
                        // }
                        );
                        game_success_bids_sum = game_success_bids_sum + bid.amount;
                    }
                };
                // vector::for_each(track_game_bids.game_bids, |bid| {
                //     let bid:GameBid = bid;
                //     if (option::some(bid.moto) == moto_winner.moto_nft) {
                //         vector::push_back(&mut game_success_bids, bid);
                //         game_success_bids_sum = game_success_bids_sum + bid.amount;
                //     }
                // });
                let mut bid_payments = vector::empty<EpochPayment>();

                index = vector::length(&game_success_bids);
                while (index > 0) {
                    index = index - 1;
                    let bid = vector::borrow(&game_success_bids, index);
                // vector::for_each(game_success_bids, |bid| {
                //     let bid:GameBid = bid;
                    let bid_final_amount_to_pay = amount_to_pay_bidders * bid.amount / game_success_bids_sum;
                    let bidder_payment = EpochPayment {
                        track_token: gs.track_token,
                        moto_token: option::some(moto_winner.moto_nft),
                        receiver_type: BIDDER,
                        amount: bid_final_amount_to_pay,
                        receiver_id: bid.bidder,
                    };
                    vector::push_back(&mut bid_payments, bidder_payment);
                };
                if (vector::length(&bid_payments) > 0) {
                    vector::append(&mut gs.epoch_payment, bid_payments);
                }

            };

            if (winner_moto_payment_amount > 0) {
                vector::push_back(&mut gs.epoch_payment, winner_moto_payment);
            };
            if (track_owner_payment_amount > 0) {
                vector::push_back(&mut gs.epoch_payment, track_owner_payment);
            };
            if (platform_payment_amount > 0) {
                vector::push_back(&mut gs.epoch_payment, platform_payment);
            };
        } else {
            let ratio_for_track = get(&motodex.percent_for_track, &gs.track_token);
            let track_owner = get(&motodex.nft_owners, &gs.track_token);
            // let ratio_for_platform = HUNDED_PERCENT_RATE - *ratio_for_track;
            let total_balance = gs.game_fees_sum + gs.game_bids_sum;
            let track_owner_payment_amount = total_balance * *ratio_for_track / HUNDED_PERCENT_RATE;// a * b / c
            let platform_payment_amount = total_balance - track_owner_payment_amount;
            let track_owner_payment = EpochPayment {
                track_token: gs.track_token,
                moto_token: option::none(),
                receiver_type: TRACK,
                amount: track_owner_payment_amount,
                receiver_id: track_owner.owner_id,
            };

            let owner = vector::borrow(&motodex.owners, 0);
            let platform_payment = EpochPayment {
                track_token: gs.track_token,
                moto_token: option::none(),
                receiver_type: PLATFORM,
                amount: platform_payment_amount,
                receiver_id: *owner,
            };
            if (track_owner_payment_amount > 0) {
                vector::push_back(&mut gs.epoch_payment, track_owner_payment);
            };
            if (platform_payment_amount > 0) {
                vector::push_back(&mut gs.epoch_payment, platform_payment);
            };
        };
        gs
    }

    fun internal_sync_epoch_game_session(track: address, motodex: &mut Motodex, clock: &Clock, ctx: &mut TxContext):FinalGameSessionView  {

        assert!(vec_map::contains(&motodex.nft_owners, &track), E_INVALID_OWNER);

        let block_timestamp = clock::timestamp_ms(clock);
        assert!(block_timestamp - motodex.latest_epoch_update >= motodex.epoch_minimal_interval, E_EPOCH_MINIMAL_INTERVALS);
        let (_, game_session_old) = vec_map::remove(&mut motodex.game_sessions, &track);
        assert!(block_timestamp - game_session_old.init_time >= motodex.min_game_session_duration, E_EPOCH_MINIMAL_INTERVALS);
        let mut game_session = internal_ping_session(game_session_old, motodex);
        assert!(vector::length(&game_session.epoch_payment) > 0, E_EPOCH_NO_PAYMENS);

        let mut payments_sum:u64 = 0;
        let mut index = vector::length(&game_session.epoch_payment);

        while (index > 0) {
            index = index - 1;
            let payment = vector::borrow(&game_session.epoch_payment, index);
            payments_sum = payments_sum + payment.amount;
        };
        assert!(payments_sum <= (game_session.game_bids_sum + game_session.game_fees_sum), E_EPOCH_GS_PAYMENTS_MORE_THAN_AVALIABLE);

        index = vector::length(&game_session.epoch_payment);

        while (index > 0) {
            index = index - 1;
            let payment = vector::borrow_mut(&mut game_session.epoch_payment, index);
            let profits = coin::take(&mut motodex.balance, payment.amount, ctx);

            transfer::public_transfer(profits, payment.receiver_id)
        };
        if (vector::length(&vec_map::keys(&motodex.game_sessions)) == 1) {
            motodex.latest_epoch_update = block_timestamp;
        };
        internal_remove_game_session(game_session_old, clock, motodex);

        let winner_account = option::borrow(&game_session.current_winner_moto).moto_owner;
        let winner_nft = option::borrow(&game_session.current_winner_moto).moto_nft;
        let winner_result = option::borrow(&game_session.current_winner_moto).last_track_time_result;

        let fin = FinalGameSessionView {
            finished_at: block_timestamp,
            track_token: track,
            winner_account,
            winner_nft,
            winner_result,
            total_attempts: game_session.attempts,
            total_balance: game_session.game_fees_sum+game_session.game_bids_sum,
            payments: game_session.epoch_payment,
        };
        // vec_map::remove(&mut motodex.game_sessions, &track);
        let event = AfterSyncSession {
            final_game_session_view: fin
        };
        // Emit the event just defined.
        event::emit(event);
        fin
    }

    fun internal_remove_game_session(session: GameSession, clock: &Clock,  motodex: &mut Motodex) {

        let mut index = vector::length(&session.moto);

        while (index > 0) {
            index = index - 1;
            let moto = vector::borrow(&session.moto, index);

            // vector::for_each(session.moto, |moto| {
            // let moto:GameSessionMoto = moto;
            let address = moto.moto_nft;
            // let object = object::address_to_object(*address);
            // object::transfer(&collection_signer, object, *option::borrow(&moto.moto_owner));
            // TODO transfer to moto_owner
            let event = ReturnNFTEvent {
                from: address,
                nft: address,
                type_nft: internal_get_type_for(address, motodex),
                timestamp: clock::timestamp_ms(clock)
            };
            // Emit the event just defined.
            event::emit(event);
            vec_map::remove(&mut motodex.nft_owners, &address);
        };
        let track_info = vec_map::get_mut(&mut motodex.nft_owners, &session.track_token);
        track_info.active_session = option::none();
    }


    fun internal_add_nft(coin: Coin<SUI>, object: &MotodexNFT,  motodex: &mut Motodex, clock: &Clock, ctx: &TxContext) {

        let minimal_fee_rate = motodex.minimal_fee;
        assert!(minimal_fee_rate > 0, PRICE_ZERO);
        assert!(coin::value(&coin) >= minimal_fee_rate, ENotEnough);

        let balance = coin.into_balance();
        motodex.balance.join(balance);

        // let coin_balance = coin::balance_mut(payment);
        // let paid = balance::split(coin_balance, minimal_fee_rate);
        //
        // // Put the coin to the Motodex's balance
        // balance::join(&mut motodex.balance, paid);

        let token_info =  TokenInfo  {
            owner_id: object.owner,
            token_type: internal_get_type_for(object::id_address(object), motodex),
            active_session: option::none(),
            collected_fee: minimal_fee_rate,
        };
        vec_map::insert(&mut motodex.nft_owners, object::id_address(object), token_info);
        let event = AddNFTEvent {
            from: tx_context::sender(ctx),
            to: @motodex_sui_contracts,
            nft: object::id_address(object),
            type_nft: internal_get_type_for(object::id_address(object), motodex),
            timestamp: clock::timestamp_ms(clock),
            value: minimal_fee_rate
        };
        // Emit the event just defined.
        event::emit(event);
        // kiosk::place(&mut motodex.kiosk, &motodex.kiosk_owner_cap, object);
        // let to = object::id_address(motodex);
        // transfer::public_transfer( object, to);
        // bag::add(
        //     kext::storage_mut(KExt{}, &mut motodex.kiosk),
        //     object::id<MotodexNFT>(&object),
        //     object
        // );
    }

    public struct CORE has drop {}
    // Part 3: Module initializer to be executed when this module is published
    fun init(otw: CORE, ctx: &mut TxContext) {//otw: MOTODEX,
        // let pub = package::claim(otw, ctx);
        // transfer::public_transfer(pub, tx_context::sender(ctx));
        sui::package::claim_and_keep(otw, ctx) ;
        internal_init_module(ctx);
    }

    // Part 4: Accessors required to read the struct attributes
    // OWNER functions
    fun check_owner(motodex: &Motodex, ctx: &TxContext) {
        let len = vector::length(&motodex.owners);
        let mut i = 0;
        let mut is_owner = false;
        let account_addr = tx_context::sender(ctx);

        while (i < len) {
            let elem = vector::borrow(&motodex.owners, i);
            if (*elem == account_addr) is_owner = true;
            i = i + 1;
        };

        assert!(is_owner == true, INVALID_SIGNER);
    }
    fun check_game_server(motodex: &Motodex, ctx: &TxContext) {
        let len = vector::length(&motodex.game_servers);
        let mut i = 0;
        let mut is_owner = false;
        let account_addr = tx_context::sender(ctx);

        while (i < len) {
            let elem = vector::borrow(&motodex.game_servers, i);
            if (*elem == account_addr) is_owner = true;
            i = i + 1;
        };

        assert!(is_owner == true, INVALID_SIGNER);
    }

    public entry fun admin_mint_nft_batch(motodex: &mut Motodex, types: vector<u8>, receivers: vector<address>, clock: &Clock, ctx: &mut TxContext) {

        check_owner(motodex,ctx);

        let mut index = vector::length(&types);

        while (index > 0) {
            index = index - 1;
            let type_nft = vector::borrow(&types, index);

            let receiver = vector::borrow(&receivers, index);
            internal_mint_nft(*receiver, *type_nft, motodex, clock, ctx);
        };
    }

    public entry fun admin_mint_nft(motodex: &mut Motodex, type_nft: u8, receiver: address, clock: &Clock, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        internal_mint_nft(receiver, type_nft, motodex, clock, ctx);
    }

    public entry fun admin_add_owner(motodex: &mut Motodex, account: address, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        vector::push_back(&mut motodex.owners, account);
    }

    public entry fun admin_remove_owner(motodex: &mut Motodex, account: address, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (finded, index) = vector::index_of(&motodex.owners, &account);
        if (finded && vector::length(&motodex.owners) > 1)  {
            vector::remove(&mut motodex.owners, index);
        }
    }

    public entry fun admin_add_game_server(motodex: &mut Motodex, account: address, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        vector::push_back(&mut motodex.game_servers, account);
    }

    public entry fun admin_remove_game_server(motodex: &mut Motodex, account: address, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (finded, index) = vector::index_of(&motodex.game_servers, &account);
        if (finded) {
            vector::remove(&mut motodex.game_servers, index);
        }
    }

    public entry fun admin_set_health_for(motodex: &mut Motodex, nft: address, health: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.token_health ,&nft);
        vec_map::insert(&mut motodex.token_health, nft, health);
    }

    public entry fun admin_set_price_main_coin_usd(motodex: &mut Motodex, price: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        motodex.price_main_coin_usd = price;
    }

    public entry fun admin_set_percent_for_track_owner(motodex: &mut Motodex, nft: address, percent: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.percent_for_track ,&nft);
        vec_map::insert(&mut motodex.percent_for_track, nft, percent);
    }

    public entry fun admin_set_price_for_type(motodex: &mut Motodex,  type_nft: u8, price: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.nfts.price_usd ,&type_nft);
        vec_map::insert(&mut motodex.nfts.price_usd, type_nft, price);
    }

    public entry fun admin_set_name_for_type(motodex: &mut Motodex,  type_nft: u8, name: String, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.nfts.name ,&type_nft);
        vec_map::insert(&mut motodex.nfts.name, type_nft, name);
    }

    public entry fun admin_set_description_for_type(motodex: &mut Motodex,  type_nft: u8, description: String, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.nfts.description ,&type_nft);
        vec_map::insert(&mut motodex.nfts.description, type_nft, description);
    }

    public entry fun admin_set_uri_for_type(motodex: &mut Motodex,  type_nft: u8, uri: std::ascii::String, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.nfts.uri ,&type_nft);
        vec_map::insert(&mut motodex.nfts.uri, type_nft, uri);
    }

    public entry fun admin_set_percent_grow(motodex: &mut Motodex,  type_nft: u8, percent_grow: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) = vec_map::remove(&mut motodex.nfts.percent_grow ,&type_nft);
        vec_map::insert(&mut motodex.nfts.percent_grow, type_nft, percent_grow);
    }

    public entry fun admin_set_minimal_fee(motodex: &mut Motodex, minimal_fee: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        motodex.minimal_fee = minimal_fee;
    }

    public entry fun admin_remove_game_session(motodex: &mut Motodex, track: address, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        let (_,_) =  vec_map::remove(&mut motodex.game_sessions, &track );
    }

    public entry fun admin_set_epoch_minimal_interval(motodex: &mut Motodex, epoch_minimal_interval: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        motodex.epoch_minimal_interval = epoch_minimal_interval;
    }

    public entry fun admin_set_min_game_session_duration(motodex: &mut Motodex, min_game_session_duration: u64, ctx: &mut TxContext) {
        check_owner(motodex,ctx);
        motodex.min_game_session_duration = min_game_session_duration;
    }

    #[allow(lint(self_transfer))]
    public fun admin_collect_profits(
        _: &OwnerCap, motodex: &mut Motodex, ctx: &mut TxContext
    ) {
        check_owner(motodex,ctx);
        let amount = balance::value(&motodex.balance);
        let profits = coin::take(&mut motodex.balance, amount, ctx);

        transfer::public_transfer(profits, tx_context::sender(ctx));
    }



    // GAME SERVER functions
    public entry fun game_server_create_or_update_game_session_for(motodex: &mut Motodex, track: address, moto: address, last_track_time_result: u64, clock: &Clock, ctx: &mut TxContext) {
        check_game_server(motodex, ctx);
        assert!(vec_map::contains(&motodex.nft_owners, &track), E_INVALID_OWNER);
        assert!(vec_map::contains(&motodex.nft_owners, &moto), E_INVALID_OWNER);
        assert!(internal_get_health_for(track, motodex) > 0, E_INVALID_HEALTH);
        assert!(internal_get_health_for(moto, motodex) > 0, E_INVALID_HEALTH);
        let (_, token_info) = vec_map::remove(&mut motodex.nft_owners, &moto);

        let mut moto_info =  TokenInfo  {
            owner_id: tx_context::sender(ctx),
            token_type: token_info.token_type,
            active_session: token_info.active_session,
            collected_fee: token_info.collected_fee,
        };
        assert!(moto_info.collected_fee > 0, E_NO_COLLECTED_FEES);
        let gs_moto = GameSessionMoto {
            moto_owner: moto_info.owner_id,
            moto_nft: moto,
            last_track_time_result,
        };

        let mut gs;
        if (vec_map::contains(&motodex.game_sessions, &track)) {
            let (_, mut gs_old) = vec_map::remove(&mut motodex.game_sessions, &track);
            let mut moto_gs = vector::empty<GameSessionMoto>();
            vector::push_back(&mut moto_gs, gs_moto);

            let current_moto_gs = gs_old.moto;
            let mut index = vector::length(&current_moto_gs) - 1;
            // let contains = false;
            while (index > 0) {
                let x = vector::remove(&mut gs_old.moto, index);
                if (x.moto_nft == moto) {
                    // do nothing, already added
                } else {
                    vector::push_back(&mut moto_gs, x);
                    index = index - 1;
                };
            };
            // if (contains == true) {
            //     // vector::remove(&mut gs_old.moto, index);
            // } else {
                gs_old.game_fees_sum = gs_old.game_fees_sum + moto_info.collected_fee;
                moto_info.collected_fee = 0;
            // };
            gs = GameSession  {
                // Time when this session was created
                init_time: gs_old.init_time,
                // Cloned track token id for ping session
                track_token: gs_old.track_token,
                moto: moto_gs,
                latest_update_time: gs_old.latest_update_time,
                latest_track_time_result: gs_old.latest_track_time_result,
                attempts: gs_old.attempts,
                game_bids_sum: gs_old.game_bids_sum,
                game_fees_sum: gs_old.game_fees_sum,
                // stored current winner
                current_winner_moto: gs_old.current_winner_moto,
                epoch_payment: gs_old.epoch_payment,
                max_moto_per_session: gs_old.max_moto_per_session,
            };

        } else {
            let mut moto_gs = vector::empty<GameSessionMoto>();
            vector::push_back(&mut moto_gs, gs_moto);
            gs = GameSession  {
                // Time when this session was created
                init_time: clock::timestamp_ms(clock),
                // Cloned track token id for ping session
                track_token: track,
                moto: moto_gs,
                latest_update_time: 0,
                latest_track_time_result: 0,
                attempts: 0,
                game_bids_sum: 0,
                game_fees_sum: moto_info.collected_fee,
                // stored current winner
                current_winner_moto: option::none(),
                epoch_payment: vector::empty<EpochPayment>(),
                max_moto_per_session: 1,
            };
        };
        if (last_track_time_result > 0) {
            gs.attempts = gs.attempts  + 1;
            gs.latest_track_time_result = last_track_time_result;
        };

        gs.latest_update_time = clock::timestamp_ms(clock);
        let mut winner = gs_moto;
        let mut index = vector::length(&gs.moto) - 1;
        while (index > 0) {
            let x = vector::remove(&mut gs.moto, index);
            if (x.last_track_time_result < winner.last_track_time_result) {
                winner = x;
            };
            vector::insert(&mut gs.moto, x, index);
            index = index - 1;
        };
        gs.current_winner_moto = option::some(winner);
        vec_map::insert(&mut motodex.game_sessions, track, gs);

        let event = CreateOrUpdateGameSession {
            from: tx_context::sender(ctx),
            track,
            moto,
            timestamp: clock::timestamp_ms(clock),
            last_track_time_result,
        };
        // Emit the event just defined.
        event::emit(event);
        vec_map::insert(&mut motodex.nft_owners, moto, token_info);
    }

    public entry fun game_server_sync_epoch( _: &OwnerCap, motodex: &mut Motodex, track: address, clock: &Clock, ctx: &mut TxContext) {
        check_game_server(motodex, ctx);
        internal_sync_epoch_game_session(track, motodex, clock, ctx);
    }

    // PUBLIC ENTRY functions
    public entry fun update_counter(motodex: &mut Motodex, clock: &Clock, ctx: &mut TxContext) {
        let event = UpdateCounterEvent {
            from: tx_context::sender(ctx),
            timestamp: clock::timestamp_ms(clock)
        };
        // Emit the event just defined.
        event::emit(event);
        motodex.counter = motodex.counter + 1;
    }

    public entry fun purchase(motodex: &mut Motodex, type_nft: u8, clock: &Clock, coin: Coin<SUI>,  ctx: &mut TxContext) {
        internal_purchase(coin, type_nft,  motodex, clock, ctx);
    }

    public entry fun add_nft(motodex: &mut Motodex, nft: &MotodexNFT, clock: &Clock, coin: Coin<SUI>,  ctx: &mut TxContext) {
        internal_add_nft(coin, nft,  motodex, clock, ctx);
    }

    public entry fun return_nft(motodex: &mut Motodex, nft: address, clock: &Clock, ctx: &mut TxContext) {
        let token_info = vec_map::get(&mut motodex.nft_owners, &nft);
        assert!(token_info.owner_id == tx_context::sender(ctx), INVALID_SIGNER);

        let (_, _) = vec_map::remove(&mut motodex.nft_owners, &nft);

        let event = ReturnNFTEvent {
            from: tx_context::sender(ctx),
            nft,
            type_nft: internal_get_type_for(nft, motodex),
            timestamp: clock::timestamp_ms(clock)
        };
        // Emit the event just defined.
        event::emit(event);
    }

    public entry fun add_health_money(motodex: &mut Motodex, nft: &MotodexNFT, clock: &Clock, coin: Coin<SUI>,  ctx: &mut TxContext) {
        let type_final = vec_map::get(&motodex.token_types ,&object::id_address(nft));
        let (_, token_health) = vec_map::remove(&mut motodex.token_health ,&object::id_address(nft));

        let price = internal_get_price_for_type(*type_final, motodex);
        assert!(price > 0, PRICE_ZERO);

        let value = price - token_health;
        assert!(value > 0, EHealthAreFull);

        //TODO transfer main coin
        assert!(coin::value(&coin) >= price, ENotEnough);
        // let coin_balance = coin::balance_mut(payment);
        // let paid = balance::split(coin_balance, value);
        //
        // // Put the coin to the Motodex's balance
        // balance::join(&mut motodex.balance, paid);
        let balance = coin.into_balance();
        motodex.balance.join(balance);

        let event = AddHealthMoney {
            from: tx_context::sender(ctx),
            nft: object::id_address(nft),
            type_nft: internal_get_type_for(object::id_address(nft), motodex),
            timestamp: clock::timestamp_ms(clock),
            value
        };
        // Emit the event just defined.
        event::emit(event);
        vec_map::insert(&mut motodex.token_health, object::id_address(nft), price);

    }

    public entry fun add_health_nft(motodex: &mut Motodex, nft: &MotodexNFT, health_nft: MotodexNFT, clock: &Clock, ctx: &mut TxContext) {
        let type_final = vec_map::get(&motodex.token_types ,&object::id_address(nft));
        let type_final_health = vec_map::get(&motodex.token_types ,&object::id_address(&health_nft));
        assert!(
            *type_final_health == HEALTH_PILL_5 ||
                *type_final_health == HEALTH_PILL_10 ||
                *type_final_health == HEALTH_PILL_30 ||
                *type_final_health == HEALTH_PILL_50
            , E_WRONG_NFT_TYPE);


        let (_, token_health) = vec_map::remove(&mut motodex.token_health ,&object::id_address(nft));

        let price = internal_get_price_for_type(*type_final, motodex);
        assert!(price > 0, PRICE_ZERO);

        let value = price - token_health;
        assert!(value > 0, EHealthAreFull);

        let event = AddHealthNFT {
            from: tx_context::sender(ctx),
            nft: object::id_address(nft),
            type_nft: internal_get_type_for(object::id_address(nft), motodex),
            timestamp: clock::timestamp_ms(clock),
            health_pill: object::id_address(&health_nft)
        };
        // Emit the event just defined.
        event::emit(event);
        vec_map::insert(&mut motodex.token_health, object::id_address(nft), price);
        let MotodexNFT {id, name, description , url , owner, type_final, health, price}= health_nft;
        object::delete(id);
    }

    public entry fun add_bid(motodex: &mut Motodex, track: &MotodexNFT, moto: &MotodexNFT, amount: u64, clock: &Clock, coin: Coin<SUI>,  ctx: &mut TxContext) {

        assert!(coin::value(&coin) >= amount, ENotEnough);
        // let coin_balance = coin::balance_mut(payment);
        // let paid = balance::split(coin_balance, amount);
        //
        // // Put the coin to the Motodex's balance
        // balance::join(&mut motodex.balance, paid);
        let balance = coin.into_balance();
        motodex.balance.join(balance);

        let mut gb = GameBid {
            amount,
            moto: object::id_address(moto),
            timestamp: clock::timestamp_ms(clock),
            bidder: tx_context::sender(ctx),
        };
        let contains_any_bids = vec_map::contains(&motodex.game_bids ,&object::id_address(track));
        if (contains_any_bids) {
            let ( _, game_bid) = vec_map::remove(&mut motodex.game_bids ,&object::id_address(track));
            let mut game_bids_vec = game_bid.game_bids;

            let mut index =vector::length(&game_bids_vec) - 1;
            let mut contains = false;
            while (index > 0) {
                let x = vector::borrow(&game_bids_vec, index);
                index = index - 1;

                if (x.moto == object::id_address(moto) && x.bidder == tx_context::sender(ctx)) {
                    contains = true;
                    break;
                };
            };

            // let (contains, index) =  vector::index_of(&game_bids_vec,
                // |x| {
            //     let x: &GameBid = x;
            //     x.moto == object::id_address(moto) && x.bidder == tx_context::sender(ctx)
            // });
            if (contains) {
                let latest_bid = vector::borrow_mut(&mut game_bids_vec, index);
                let amount_latest = latest_bid.amount;
                gb.amount = gb.amount + amount_latest;
                vector::remove(&mut game_bids_vec, index);
                vector::push_back(&mut game_bids_vec, gb);
            } else {
                vector::push_back(&mut game_bids_vec, gb);
            };
            let tgb = TrackGameBid  {
                // id: object::new(ctx),
                game_bids: game_bids_vec
            };
            vec_map::insert(&mut motodex.game_bids ,object::id_address(track), tgb);
            // let TrackGameBid {  game_bids } = game_bid;
            // object::delete(id);

        } else {
            let mut game_bids = vector::empty<GameBid>();
            vector::push_back(&mut game_bids, gb);
            let tgb =  TrackGameBid  {
                // id: object::new(ctx),
                game_bids
            };
            vec_map::insert(&mut motodex.game_bids ,object::id_address(track), tgb);
        };
        let ( _, mut gs) = vec_map::remove(&mut motodex.game_sessions ,&object::id_address(track));
        gs.game_bids_sum = gs.game_bids_sum + amount;
        vec_map::insert(&mut motodex.game_sessions ,object::id_address(track), gs);

        let event = AddBid {
            bidder: tx_context::sender(ctx),
            track: object::id_address(track),
            moto: object::id_address(moto),
            timestamp: clock::timestamp_ms(clock),
            amount
        };
        // Emit the event just defined.
        event::emit(event);

    }


    // PUBLIC VIEW functions

    public fun get_counter(motodex: &Motodex):u256  {    //public function
        motodex.counter
    }

    public fun get_total_supply(motodex: &Motodex):u256  {    //public function
        motodex.total_supply
    }

    public fun get_owners(motodex: &Motodex):vector<address>  {    //public function
        motodex.owners
    }


    public fun get_price_for_type_usd(motodex: &Motodex,  type_nft: u8):u64  {    //public function
        internal_get_price_for_type_usd(type_nft, motodex)
    }

    public fun get_price_for_type(motodex: &Motodex,  type_nft: u8):u64  {    //public function
        internal_get_price_for_type(type_nft, motodex)
    }

    public fun get_price_main_coin_usd(motodex: &Motodex):u64  {    //public function
        motodex.price_main_coin_usd
    }

    public fun get_type_for(motodex: &Motodex,  nft: address):u8  {    //public function
        internal_get_type_for(nft, motodex)
    }

    public fun get_health_for(motodex: &Motodex,  nft: address):u64  {    //public function
        internal_get_health_for(nft, motodex)
    }

    public fun get_percent_for_track_owner(motodex: &Motodex,  nft: address):u64  {    //public function
        *vec_map::get(&motodex.percent_for_track, &nft)
    }

    public fun get_minimal_fee(motodex: &Motodex):u64  {    //public function
        motodex.minimal_fee
    }

    public fun get_game_servers(motodex: &Motodex):vector<address>  {    //public function
        motodex.game_servers
    }

    public fun get_nft_owners(motodex: &Motodex):VecMap<address, TokenInfo>  {    //public function
        motodex.nft_owners
    }

    public fun get_game_sessions(motodex: &Motodex):VecMap<address, GameSession>  {    //public function
        motodex.game_sessions
    }

    public fun get_game_bids(motodex: &Motodex):VecMap<address, TrackGameBid>  {
        // let gb = vec_map::empty();
        // let keys = vec_map::keys(&motodex.game_bids);
        // let index = vector::length(&keys);
        //
        // while (index > 0) {
        //     index = index - 1;
        //     let key = vector::borrow(&keys, index);
        //     let value = vec_map::get(&motodex.game_bids, key);
        //     let game_bids = vector::empty();
        //     let index_game_bids = vector::length(&value.game_bids);
        //
        //     while (index_game_bids > 0) {
        //         index_game_bids = index_game_bids - 1;
        //         let b = vector::borrow(&value.game_bids, index_game_bids);
        //         vector::push_back(&mut game_bids, b);
        //     };
        //     vec_map::insert(&mut gb, *key, game_bids);
        // };
        // gb
        // vec_map::get(&motodex.game_bids, )
        motodex.game_bids
    }

    public fun get_latest_epoch_update(motodex: &Motodex):u64  {    //public function
        motodex.latest_epoch_update
    }



    #[test]
    fun test_point_new_and_move() {
        // let ctx = &mut tx_context::dummy();
        // let motodex = internal_init_module(ctx);
        // let (bernard, manny, fran) = (@0x1, @0x2, @0x3);
        //
        // admin_mint_nft(motodex, 0, bernard, ctx);

    }
}
