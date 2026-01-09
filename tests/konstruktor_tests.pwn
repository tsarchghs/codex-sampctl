// tests/konstruktor_tests.pwn

forward RunKonstruktorTests();

stock bool:file_exists(const name[])
{
    new File:h = fopen(name, io_read);
    if (h == 0) return false;
    fclose(h);
    return true;
}

// Basic assertion helper
stock TestAssert(bool:cond, const testname[], const errmsg[])
{
    if (cond)
    {
        printf("[TEST PASS] %s", testname);
        return true;
    }
    else
    {
        printf("[TEST FAIL] %s - %s", testname, errmsg);
        return false;
    }
}

public RunKonstruktorTests()
{
    new playerid = 0; // test player index (server-side only)

    // Ensure arrays exist & clear item state
    for (new i = 0; i < MAX_ITEMS; i++) PlayerItems[playerid][i] = 0;

    // Prepare logging file
    new file[128];
    format(file, sizeof(file), "tests/results_konstruktor.txt");
    new File:f = fopen(file, io_write);
    if (f == 0)
    {
        printf("[TEST] Could not open results file: %s", file);
    }

    // Test 1: Charcoal batch start & pickup
    PlayerItems[playerid][ITEM_WOOD_STACK] = 1;
    TestAssert(Constructor_Test_StartCharcoal(playerid) == 1, "Charcoal start", "Start failed");
    TestAssert(gCharcoalOvenOccupied == true, "Charcoal oven occupied flag", "Not occupied");
    // Fast-forward ready state
    gCharcoalOvenReadyTick = GetTickCount() - 1;
    TestAssert(Constructor_Test_PickupCharcoal(playerid) == 1, "Charcoal pickup", "Pickup failed or inventory full");
    TestAssert(PlayerItems[playerid][ITEM_CHARCOAL] == 1, "Charcoal in inventory", "No charcoal added");

    // Test 2: Mining success and cart creation
    // Force success to avoid flakiness
    PlayerItems[playerid][ITEM_PICKAXE] = 1;
    new ore = Constructor_Test_MineOnce(playerid, true);
    TestAssert(ore == ITEM_IRON_ORE || ore == ITEM_BAUXITE_ORE, "Mining success returns ore type", "No ore returned");
    TestAssert(PlayerItems[playerid][ore] == 1, "Ore in inventory after mining", "Ore not in inventory");
    TestAssert(gConstructorCart[playerid] != INVALID_OBJECT_ID, "Cart object created", "Cart missing");

    // Test 3: Smelter start & pickup
    PlayerItems[playerid][ITEM_CHARCOAL] = 1; // ensure charcoal
    if (PlayerItems[playerid][ITEM_IRON_ORE] > 0) PlayerItems[playerid][ITEM_IRON_ORE] = 1;
    else PlayerItems[playerid][ITEM_BAUXITE_ORE] = 1;
    TestAssert(Constructor_Test_StartSmelter(playerid) == 1, "Smelter start", "Start failed (missing materials?)");
    TestAssert(gSmelterOccupied == true, "Smelter occupied flag", "Not occupied");
    gSmelterReadyTick = GetTickCount() - 1;
    TestAssert(Constructor_Test_PickupSmelted(playerid) == 1, "Smelter pickup", "Pickup failed or inventory full");

    // Clean up cart object
    Constructor_DestroyCart(playerid);

    // Write summary to file
    if (f != 0)
    {
        fwrite(f, "Konstruktor tests finished. Check server console for details.\n");
        fclose(f);
    }

    printf("[TEST] Konstruktor tests completed");
    return 1;
}
