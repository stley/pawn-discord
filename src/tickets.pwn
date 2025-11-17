/*
Ticket System Bot, entirely written in Pawn using Discord-Connector.
Thanks to:
    - maddinat0r for discord-connector
    - IS4 for PawnPlus plugin
    - open.mp development team, The - for making such a customizable and modular binary
*/

#define FILTERSCRIPT
#include <default>
#include <float>
#include <omp-database>
#include <string>
//#include <sscanf2-barebone>
#include <PawnPlus>
#include <discord-connector>


#pragma option -d3

new Pool:globalGuildPool;
new DB:globalDatabase; //For now, then I will switch to MySQL
//static MySQL:globalDatabase;
new List:commandsList

enum guildStructure{
    DCC_Guild:gs_guildID,
    DCC_User:gs_guildOwner,
    DCC_Role:gs_StaffMembers,
    DCC_Channel:gs_Lobby,
    Pool:activeTickets,
    
}

enum ticketStructure{
    DCC_Guild:ticketGuild,
    DCC_Channel:ticketChannel,
    DCC_User:ticketIssuer,
    DCC_User:ticketAsignee,
    DCC_Role:ticketRoleAsignee
}


main(){}

forward OnFilterScriptInit();
forward OnFilterScriptExit();
native format(output[], len = sizeof (output), const format[], {Float, _}:...);


public OnFilterScriptInit(){
    printf("Starting Discord bot...");
    globalGuildPool = pool_new();
    commandsList = list_new();
    globalDatabase = DB_Open("pawnbot.db", SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX);
    if(globalDatabase == DB:0) printf("Error loading the database.");
    getActiveGuilds();
    registerCommands();
}
public OnFilterScriptExit(){
    pool_delete_deep(globalGuildPool);
    DB_Close(globalDatabase);
}

getActiveGuilds(){
    printf("Loading active guilds...");
    new DBResult:guildCache = DB_ExecuteQuery(globalDatabase, "SELECT * FROM ticket_guilds");
    new rowcount = DB_GetRowCount(guildCache);
    new processed_rows;
    
    printf("%d", rowcount);
    while(processed_rows < rowcount){
        if(!guildCache) return 1;
        new guildMap[guildStructure];
        new discordIds[DCC_ID_SIZE];
        //new Map:guildMap = map_new();
        DB_GetFieldStringByName(guildCache, "guildID", discordIds, DCC_ID_SIZE);
        printf("Guild ID: %s", discordIds);
        guildMap[gs_guildID] = DCC_FindGuildById(discordIds);
        DB_GetFieldStringByName(guildCache, "guildOwner", discordIds, DCC_ID_SIZE);
        
        printf("Guild Owner is: %s", discordIds);
        guildMap[gs_guildOwner] = DCC_FindUserById(discordIds);
        DB_GetFieldStringByName(guildCache, "guildStaffRole", discordIds, DCC_ID_SIZE);
        printf("Guild Staff Role is: %s", discordIds);
        guildMap[gs_StaffMembers] = DCC_FindRoleById(discordIds);

        DB_GetFieldStringByName(guildCache, "guildLobby", discordIds, DCC_ID_SIZE);
        printf("Ticket Lobby Channel ID is: %s", discordIds);
        guildMap[gs_Lobby] = DCC_FindChannelById(discordIds);

        guildMap[activeTickets] = pool_new();

        getActiveTickets(pool_add_arr(globalGuildPool, guildMap));

        DB_SelectNextRow(guildCache);
        processed_rows++;
    }
    return 1;
}

getActiveTickets(globalGuildPoolIndex){
    return 1;
}
updateTicketLobby(p) return 1;

public DCC_OnGuildCreate(DCC_Guild:guild){
    new new_guildInt[DCC_ID_SIZE];
    DCC_GetGuildId(guild, new_guildInt);
    printf("OnGuildCreate: %s", new_guildInt);
    for(new i; i < pool_size(globalGuildPool); i++){
        if(!pool_has(globalGuildPool, i)) continue;
        new guildArr[guildStructure];
        pool_get_arr(globalGuildPool, i, guildArr);
        //new Map:guildMap = Map:pool_get(globalGuildPool, i);
        new guildInteger[DCC_ID_SIZE];
        DCC_GetGuildId(guildArr[gs_guildID], guildInteger);
        if(!strequal(guildInteger, new_guildInt, true)) continue;
        else{
            printf("Guild already exists on database, skipping.");
            return 1;
        } 
    }
    new newGuildMap[guildStructure];
    new guildOwnerID[DCC_ID_SIZE];
    
    newGuildMap[gs_guildID] = guild;

    DCC_GetGuildOwnerId(guild, guildOwnerID);
    newGuildMap[gs_guildOwner] = DCC_FindUserById(guildOwnerID);

    newGuildMap[gs_StaffMembers] = DCC_Role:0;

    newGuildMap[gs_Lobby] = DCC_Channel:0;
    newGuildMap[activeTickets] = pool_new();

    createNewGuildRegistry(pool_add_arr(globalGuildPool, newGuildMap));

    return 1;
}

stock DCC_GetGuildChannelId(DCC_Guild:guild, const channel_name[], &DCC_Channel:channel){
    new channel_count;
    DCC_GetGuildChannelCount(guild, channel_count);
    for(new c; c < channel_count; c++){
        new DCC_Channel:curr_channel;
        new channelName[DCC_ID_SIZE];
        DCC_GetGuildChannel(guild, c, curr_channel);
        DCC_GetChannelName(curr_channel, channelName);
        if(strequal(channelName, channel_name)){
            channel = curr_channel;
            break;
        }
        continue;
    }
}

native DBResult:DB_ExecuteQuery_s(DB:db, ConstAmxString:query) = DB_ExecuteQuery;

createNewGuildRegistry(gPool_index){
    new 
        Map:guildMap = Map:pool_get(globalGuildPool, gPool_index),
        _guildID[DCC_ID_SIZE],
        _guildOwner[DCC_ID_SIZE];/*,
        _main_channel[DCC_ID_SIZE],
        _staff_role[DCC_ID_SIZE]
    ;*/
    DCC_GetGuildId(DCC_Guild:map_get(guildMap, gs_guildID), _guildID);
    DCC_GetUserId(DCC_User:map_get(guildMap, gs_guildOwner), _guildOwner);
    //DCC_GetChannelId(DCC_Channel:map_get(guildMap, gs_Lobby), _main_channel);
    DB_FreeResultSet(
        DB_ExecuteQuery_s(globalDatabase, str_format("INSERT INTO ticket_guilds VALUES ('%q', '%q', 'nil', 'nil')", _guildID, _guildOwner))
    );
    return 1;
}




IsGuildOwner(DCC_Guild:guild, DCC_User:user){
    new
        argGuild[DCC_ID_SIZE],
        argUser[DCC_ID_SIZE]    
    ;
    DCC_GetGuildId(guild, argGuild);
    DCC_GetUserId(user, argUser);
    print("GUILD ID:");
    print(argGuild);
    print("USER ID:");
    print(argUser);
    for(new p; p < pool_size(globalGuildPool); p++){
        if(!pool_has(globalGuildPool, p)) continue;
        new guildStruct[guildStructure];
        pool_get_arr(globalGuildPool, p, guildStruct);
        new
            getGuild[DCC_ID_SIZE],
            getUser[DCC_ID_SIZE]
        ;
        printf("DCC_GuildId: %d | DCC_User:%d", _:guildStruct[gs_guildID], _:guildStruct[gs_guildOwner]);
        DCC_GetGuildId(guildStruct[gs_guildID], getGuild);
        DCC_GetUserId(guildStruct[gs_guildOwner], getUser);
        print("GUILD ID:");
        print(getGuild);
        print("USER ID:");
        print(getUser);
        if(!strequal(getGuild, argGuild, true)) continue;
        if(!strequal(argUser, getUser, true)) return 0;
        else return 1;
    }
    return 0;
}


updateGuildConfig(globalGuildPoolIndex){
    if(!pool_has(globalGuildPool, globalGuildPoolIndex)) return 0;
    new guildStruct[guildStructure];
    pool_get_arr(globalGuildPool, globalGuildPoolIndex, guildStruct);
    new
        getUser[DCC_ID_SIZE],
        getRole[DCC_ID_SIZE],
        getLobby[DCC_ID_SIZE]
    ;
    DCC_GetUserId(guildStruct[gs_guildOwner], getUser);
    DCC_GetRoleId(guildStruct[gs_StaffMembers], getRole);
    DCC_GetChannelId(guildStruct[gs_Lobby], getLobby);
    DB_FreeResultSet(
        DB_ExecuteQuery_s(globalDatabase, str_format("UPDATE ticket_guilds SET guildOwner = '%q', guildStaffRole = '%q', guildLobby = '%q'", getUser, getRole, getLobby))
    );
    return 1;
}


#include "../src/modules/commands.p"