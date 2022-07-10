public class StreetVendorsSystem extends ScriptableSystem {
    private func OnAttach() -> Void {
        let interactionPromptCallback: ref<StreetVendorsInteractionPrompt_Callback> = new StreetVendorsInteractionPrompt_Callback();
        interactionPromptCallback.gameInstance = this.GetGameInstance();
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(interactionPromptCallback, 0);
    }

    private func OnDetach() -> Void {
    }
}

public class GlobalInputListener {
    let game: GameInstance;
    protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
        if Equals(ListenerAction.GetName(action), n"one_click_confirm") && ListenerAction.IsButtonJustReleased(action) {
            let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.game).Get(GetAllBlackboardDefs().UI_System);
            let uiSystemBB: ref<UI_SystemDef> = GetAllBlackboardDefs().UI_System;
            if(!blackboard.GetBool(uiSystemBB.IsInMenu) && IsPlayerLookingAtStreetVendor(this.game)){
                let vendorGameObject: ref<GameObject> = GetLookAtObject(this.game);
                let vendor: ref<Vendor> = MarketSystem.GetInstance(this.game).GetVendor(vendorGameObject);
                let marketSystem: ref<MarketSystem> = MarketSystem.GetInstance(this.game);
                if(!ArrayContains(marketSystem.m_readyStreetVendors, vendor)){
                    for igsPools in marketSystem.m_igsPools {
                        if(Equals(igsPools.vendorTypeTarget, vendor.GetVendorType())){
                            marketSystem.GenerateStreetVendorInventory(vendor, igsPools.itemPool, new Vector2(Cast<Float>(igsPools.poolQuantityMin), Cast<Float>(igsPools.poolQuantityMax)), new Vector2(Cast<Float>(igsPools.itemQuantityMin), Cast<Float>(igsPools.itemQuantityMax)));
                        }
                    }
                    vendor.AddItemsToStock(MakeItemStack("Items.money", FloorF(RandRangeF(1450, 5230)), true));
                    ArrayPush(marketSystem.m_readyStreetVendors, vendor);
                }
                let marketRequest = new AttachVendorRequest();
                marketRequest.owner = vendorGameObject;
                marketRequest.vendorID = vendor.m_tweakID;
                MarketSystem.GetInstance(this.game).QueueRequest(marketRequest);
                let vendorPanelData = new VendorPanelData();
                let vendorData: VendorData;
                vendorData.vendorId = ToString(vendor.GetVendorRecord());
                vendorData.entityID = vendorGameObject.GetEntityID();
                vendorData.isActive = true;
                vendorPanelData.data = vendorData;
                GameInstance.GetUISystem(this.game).RequestVendorMenu(vendorPanelData, n"MenuScenario_Vendor");
            }
        }
    }
}

/*Inventory Generation System*/
public class igsPool {
    let vendorTypeTarget: gamedataVendorType;
    let itemPool: array<String>;
    let poolQuantityMin: Int32;
    let poolQuantityMax: Int32;
    let itemQuantityMin: Int32;
    let itemQuantityMax: Int32;
}

public static final func CreateIGSPool(vendorType: gamedataVendorType, itemPool: array<String>, poolQuantityMin: Int32, poolQuantityMax: Int32, itemQuantityMin: Int32, itemQuantityMax: Int32) -> ref<igsPool> {
    let output = new igsPool();
    output.vendorTypeTarget = vendorType;
    output.itemPool = itemPool;
    output.poolQuantityMin = poolQuantityMin;
    output.poolQuantityMax = poolQuantityMax;
    output.itemQuantityMin = itemQuantityMin;
    output.itemQuantityMax = itemQuantityMax;
    return output;
}

public static final func InitNewIGSPool(gameInstance: GameInstance, igsPool: ref<igsPool>) -> Bool {
    let marketSystem = MarketSystem.GetInstance(gameInstance);
    if(ArrayContains(marketSystem.m_igsPools, igsPool)) {
        return false;
    }else{
        ArrayPush(marketSystem.m_igsPools, igsPool);
        return true;
    }
}

/*PlayerPuppet*/
@addField(PlayerPuppet)
private let m_streetVendorsInputListener: ref<GlobalInputListener>;
@addField(PlayerPuppet)
let m_lookingAtStreetVendor: Bool;
@addField(PlayerPuppet)
let m_readyToInteractWithStreetVendor: Bool;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    wrappedMethod();

    this.m_streetVendorsInputListener = new GlobalInputListener();
    this.m_streetVendorsInputListener.game = this.GetGame();
    this.RegisterInputListener(this.m_streetVendorsInputListener);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
    wrappedMethod();

    this.UnregisterInputListener(this.m_streetVendorsInputListener);
    this.m_streetVendorsInputListener = null;
}

/*MarketSystem*/
@addField(MarketSystem)
private let m_initialIGSOnVendors: array<ref<Vendor>>;

@addField(MarketSystem)
private let m_readyStreetVendors: array<ref<Vendor>>;

@addField(MarketSystem)
private let m_igsPools: array<ref<igsPool>>;

@addMethod(MarketSystem)
public static func IsRedscriptStreetVendors() -> Bool {
    return true;
}

@addMethod(MarketSystem)
private final func ClearStreetVendorInventory(vendor: ref<Vendor>) {
    ArrayClear(vendor.m_stock);
}

@addMethod(MarketSystem)
private final func GenerateStreetVendorInventory(vendor: ref<Vendor>, items: array<String>, mainQuantity: Vector2, mainMinMax: Vector2) {
    vendor.m_inventoryInit = false;
    vendor.m_lastInteractionTime = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp();
    if(!ArrayContains(this.m_initialIGSOnVendors, vendor)) {
        vendor.FillVendorInventory(false);
        this.ClearStreetVendorInventory(vendor);
        ArrayPush(this.m_initialIGSOnVendors, vendor);
    }
    for item in GenerateRandomArray(items, FloorF(RandRangeF(mainQuantity.X, mainQuantity.Y))) {
        vendor.AddItemsToStock(MakeItemStack(item, FloorF(RandRangeF(mainMinMax.X, mainMinMax.Y)), true));
    }
}

/*Native Functions*/
public static final func MakeItemStack(itemName: String, quantity: Int32, available: Bool) -> SItemStack {
    let itemID = ItemID.FromTDBID(TDBID.Create(itemName));
    let itemStack: SItemStack;
    itemStack.itemID = itemID;
    itemStack.quantity = quantity;
    itemStack.isAvailable = available;
    return itemStack;
}

public static final func GenerateRandomArray(array: array<String>, newLenght: Int32) -> array<String> {
    let generated = 0;
    let generatedArray: array<String>;
    let newLenght = newLenght;
    if newLenght > ArraySize(array){
        newLenght = ArraySize(array);
    }
    while generated < newLenght {
        let newRandom = array[RandRange(0, ArraySize(array))];
        if(!ArrayContains(generatedArray, newRandom)) {
            ArrayPush(generatedArray, newRandom);
            generated += 1;
        }
    }
    return generatedArray;
}

public static final func GetLookAtObject(gameInstance: GameInstance) -> ref<GameObject> {
    let player = GetPlayer(gameInstance);
    let targetingSystem: ref<TargetingSystem> = GameInstance.GetTargetingSystem(gameInstance);
    let targetObject: ref<GameObject> = targetingSystem.GetLookAtObject(player, false, false);
    return targetObject;
}

public static final func IsPlayerLookingAtStreetVendor(gameInstance: GameInstance) -> Bool {
    let player = GetPlayer(gameInstance);
    let targetObject: ref<GameObject> = GetLookAtObject(gameInstance);
    let distance = Vector4.Distance(player.GetWorldPosition(), targetObject.GetWorldPosition());
    if(IsGameObjectStreetVendor(gameInstance, targetObject) && distance < 3.0){
        return true;
    }
    return false;
}

public static final func IsGameObjectStreetVendor(gameInstance: GameInstance, gameObject: ref<GameObject>) -> Bool {
    let player = GetPlayer(gameInstance);
    if(gameObject.IsNPC()){
        let npc: ref<NPCPuppet> = gameObject as NPCPuppet;
        let npcRecord: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(GameObject.GetTDBID(gameObject));
        let vendor: ref<Vendor> = MarketSystem.GetInstance(gameInstance).GetVendor(gameObject);
        let v_EntityID: EntityID = PersistentID.ExtractEntityID(vendor.GetVendorPersistentID());
        let v_IsDefined: Bool = EntityID.IsDefined(v_EntityID);
        let distance = Vector4.Distance(player.GetWorldPosition(), gameObject.GetWorldPosition());
        if(v_IsDefined && npcRecord.IsCrowd()) {
            return true;
        }
    }
    return false;
}

/*Inspired by psiberx's implementation*/
public static final func CreateInteractionChoice(action: CName, title: String) -> InteractionChoiceData {
    let choiceData: InteractionChoiceData;
    choiceData.localizedName = title;
    choiceData.inputAction = action;

    let choiceType: ChoiceTypeWrapper;
    ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
    choiceData.type = choiceType;

    return choiceData;
}

public static final func PrepareVisualizersInfo(hub: InteractionChoiceHubData) -> VisualizersInfo {
    let visualizersInfo: VisualizersInfo;
    visualizersInfo.activeVisId = hub.id;
    visualizersInfo.visIds = [ hub.id ];

    return visualizersInfo;
}

public static final func CreateInteractionHub(game: GameInstance, titel: String, action: CName, active: Bool) {
    let choiceHubData: InteractionChoiceHubData;
    choiceHubData.id = -1002;
    choiceHubData.active = active;
    choiceHubData.flags = IntEnum<EVisualizerDefinitionFlags>(0);
    choiceHubData.title = titel;

    let choices: array<InteractionChoiceData>;
    ArrayPush(choices, CreateInteractionChoice(action, titel));
    choiceHubData.choices = choices;

    let visualizersInfo = PrepareVisualizersInfo(choiceHubData);

    let blackboardDefs = GetAllBlackboardDefs();
    let interactionBB = GameInstance.GetBlackboardSystem(game).Get(blackboardDefs.UIInteractions);
    interactionBB.SetVariant(blackboardDefs.UIInteractions.InteractionChoiceHub, ToVariant(choiceHubData), true);
    interactionBB.SetVariant(blackboardDefs.UIInteractions.VisualizersInfo, ToVariant(visualizersInfo), true);
}
/**/

/*Calls*/
public class StreetVendorsInteractionPrompt_Callback extends DelayCallback {
    public let gameInstance: GameInstance;
    public func Call() -> Void {
        StreetVendorsInteractionPrompt(this.gameInstance);
    }
}

private func StreetVendorsInteractionPrompt(gameInstance: GameInstance) {
    let interactionPromptCallback: ref<StreetVendorsInteractionPrompt_Callback> = new StreetVendorsInteractionPrompt_Callback();
    interactionPromptCallback.gameInstance = gameInstance;
    let player: ref<PlayerPuppet> = GetPlayer(gameInstance);
    if(IsPlayerLookingAtStreetVendor(gameInstance)) {
        player.m_lookingAtStreetVendor = true;
    }else{
        player.m_lookingAtStreetVendor = false;
    }
    if(player.m_lookingAtStreetVendor) {
        player.m_lookingAtStreetVendor = false;
        let vendorObject: ref<GameObject> = GetLookAtObject(gameInstance);
        let vendorCharRecord: ref<Character_Record> = TweakDBInterface.GetCharacterRecord(GameObject.GetTDBID(vendorObject));
        let output: String = GetLocalizedText("LocKey#553")+": "+GetLocalizedTextByKey(vendorCharRecord.DisplayName());
        CreateInteractionHub(gameInstance, output, n"UI_Apply", true);
        player.m_readyToInteractWithStreetVendor = true;
    }else{
        if(player.m_readyToInteractWithStreetVendor) {
            CreateInteractionHub(gameInstance, "", n"UI_Apply", false);
        }
        player.m_readyToInteractWithStreetVendor=false;
    }
    GameInstance.GetDelaySystem(gameInstance).DelayCallback(interactionPromptCallback, 0);
}