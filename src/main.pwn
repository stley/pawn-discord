#define FILTERSCRIPT
#include <default>
#include <float>
#include <omp-database>
#include <string>
#include <PawnPlus>
#include <discord-connector>

#pragma option -d3

static Pool:globalGuildPool;
static DB:globalDatabase;

enum guildStructure{
    DCC_Guild:gs_guildID,
    DCC_User:gs_guildOwner,
    DCC_Channel:gs_main_channel
}


#define main_channel_name    "pawn-bot"

main(){}

forward OnFilterScriptInit();
forward OnFilterScriptExit();
native format(output[], len = sizeof (output), const format[], {Float, _}:...);


public OnFilterScriptInit(){
    printf("Starting Discord bot...");
    globalGuildPool = pool_new();
    globalDatabase = DB_Open("pawnbot.db", SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX);
    if(globalDatabase == DB:0) printf("Error when loading the database.");
    getActiveGuilds();
    sendInitMessage();
}
public OnFilterScriptExit(){
    pool_delete_deep(globalGuildPool);
    DB_Close(globalDatabase);
}


sendInitMessage(){
    for(new p; p < pool_size(globalGuildPool); p++){
        if(!pool_has(globalGuildPool, p)) continue;
        new 
            Map:tempGuild = Map:pool_get(globalGuildPool, p),
            msg[256],
            guildown[DCC_ID_SIZE],
            thisGuild[DCC_ID_SIZE],
            thisChannel[DCC_ID_SIZE]
        ;
        DCC_GetGuildId(DCC_Guild:map_get(tempGuild, gs_guildID), thisGuild);
        DCC_GetUserId(DCC_User:map_get(tempGuild, gs_guildOwner), guildown);
        DCC_GetChannelId(DCC_Channel:map_get(tempGuild, gs_main_channel), thisChannel);
        format(msg, sizeof msg, "Owner: <@!%s> | Guild ID: %s | Este canal tiene el ID: %s", guildown, thisGuild, thisChannel);
        DCC_SendChannelMessage(DCC_Channel:map_get(tempGuild, gs_main_channel), msg);
        continue;
    }
    return 1;
}

getActiveGuilds(){
    printf("Loading active guilds...");
    new DBResult:guildCache = DB_ExecuteQuery(globalDatabase, "SELECT * FROM guilds");
    new rowcount = DB_GetRowCount(guildCache);
    new processed_rows;
    printf("%d", rowcount);
    while(processed_rows < rowcount){
        if(!guildCache) return 1;
        new discordIds[DCC_ID_SIZE];
        new Map:guildMap = map_new();
        DB_GetFieldStringByName(guildCache, "guildID", discordIds, DCC_ID_SIZE);
        printf("Guild ID: %s ", discordIds);
        map_set(guildMap, gs_guildID, _:DCC_FindGuildById(discordIds));
        DB_GetFieldStringByName(guildCache, "guildOwner", discordIds, DCC_ID_SIZE);
        printf("Guild Owner is: %s ", discordIds);
        map_set(guildMap, gs_guildOwner, _:DCC_FindUserById(discordIds))
        DB_GetFieldStringByName(guildCache, "guildMainChannel", discordIds, DCC_ID_SIZE);
        printf("Guild Main Channel ID is: %s ", discordIds);
        map_set(guildMap, gs_main_channel, _:DCC_FindChannelById(discordIds));
        pool_add(globalGuildPool, guildMap);
        DB_SelectNextRow(guildCache);
        processed_rows++;
    }
    return 1;
}

public DCC_OnGuildCreate(DCC_Guild:guild){
    new new_guildInt[DCC_ID_SIZE];
    DCC_GetGuildId(guild, new_guildInt);
    printf("OnGuildCreate: %s", new_guildInt);
    for(new i; i < pool_size(globalGuildPool); i++){
        if(!pool_has(globalGuildPool, i)) continue;
        new Map:guildMap = Map:pool_get(globalGuildPool, i);
        new guildInteger[DCC_ID_SIZE];
        DCC_GetGuildId(DCC_Guild:map_get(guildMap, gs_guildID), guildInteger);
        if(!strequal(guildInteger, new_guildInt, true)) continue;
        else{
            printf("Guild already exists on database, skipping.");
            return 1;
        } 
    }
    new Map:newGuildMap = map_new();
    new guildOwnerID[DCC_ID_SIZE];
    map_add(newGuildMap, gs_guildID, _:guild);
    DCC_GetGuildOwnerId(guild, guildOwnerID);
    map_add(newGuildMap, gs_guildOwner, _:DCC_FindUserById(guildOwnerID));
    map_add(newGuildMap, gs_main_channel, _:DCC_FindChannelByName(main_channel_name));
    
    createNewGuildRegistry(pool_add(globalGuildPool, newGuildMap));
    return 1;
}


createNewGuildRegistry(gPool_index){
    new 
        Map:guildMap = Map:pool_get(globalGuildPool, gPool_index),
        _guildID[DCC_ID_SIZE],
        _guildOwner[DCC_ID_SIZE],
        _main_channel[DCC_ID_SIZE]
    ;
    DCC_GetGuildId(DCC_Guild:map_get(guildMap, gs_guildID), _guildID);
    DCC_GetUserId(DCC_User:map_get(guildMap, gs_guildOwner), _guildOwner);
    DCC_GetChannelId(DCC_Channel:map_get(guildMap, gs_main_channel), _main_channel);
    new query[200];
    format(query, sizeof(query), "INSERT INTO guilds VALUES ('%q', '%q', '%q')", _guildID, _guildOwner, _main_channel);
    DB_FreeResultSet(
        DB_ExecuteQuery(globalDatabase, query)
    );
    return 1;
}