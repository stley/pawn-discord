new Pool:globalGuildPool;
new List:guildCommandsList;


enum guildStruct{
    DCC_Guild:guildID,
    DCC_User:guildOwner,
    DCC_Role:guildBotManager,
    Pool:ticketPool,
    Map:structConfig
};

enum guildConfiguration{
    DCC_Channel:guildLobby,
    List:guildRoleAsignees
};

forward saveGuilds();
public saveGuilds(){
    task_yield(1);
    for(new p; p < pool_size(globalGuildPool); p++){
        updateGuild(p);
    }
    return 1;
}


loadGuilds(){
    task_yield(1);
    print("Loading existent guilds...");
    await mysql_aquery(mainDatabase, "SELECT * FROM guilds");
    new
        rows = cache_num_rows(),
        loaded = 0
    ;
    printf("%d existent guilds entries found", rows);
    if(!rows) return 1;
    for(new row; row < rows; row++){
        new
            discordId[DCC_ID_SIZE],
            guild[guildStruct]
        ;
        printf("fetching Guild from ROW %d", row);
        cache_get_value_name(row, "guildID", discordId);
        printf("Guild ID: %s", discordId);
        guild[guildID] = DCC_FindGuildById(discordId);
        DCC_GetGuildOwnerId(guild[guildID], discordId);
        printf("Guild Owner ID: %s", discordId);
        guild[guildOwner] = DCC_FindUserById(discordId);
        cache_get_value_name(row, "guildBotManagerID", discordId);
        printf("Guild Bot Manager Role ID: %s", discordId);
        guild[guildBotManager] = DCC_FindRoleById(discordId);
        guild[ticketPool] = pool_new();
        guild[structConfig] = map_new();
        new globalIndex = pool_add_arr(globalGuildPool, guild);
        loadGuildConfig(globalIndex);
        printf("Guild row %d added at global pool (index %d).", row, globalIndex);
        loaded++;
        break;
    }
    printf("%d guild%sloaded from database.", loaded, (loaded>1) ? "s ": " ");
    loadGuildCommands();
    return 0;
}


deleteGuild(poolIndex){
    if(!pool_has(globalGuildPool, poolIndex)) return 0;
    new guild[guildStruct];
    pool_get_arr(globalGuildPool, poolIndex, guild);
    pool_remove_deep(globalGuildPool, poolIndex);

    new query[96];
    new getGuildID[DCC_ID_SIZE];
    DCC_GetGuildId(guild[guildID], getGuildID);
    mysql_format(mainDatabase, query, sizeof(query), "DELETE FROM guilds WHERE guildID = '%e' LIMIT 1", getGuildID);
    mysql_pquery(mainDatabase, query);
    return 1;
}

createGuild(poolIndex){
    
    if(!pool_has(globalGuildPool, poolIndex)) return 0;
    new guild[guildStruct];
    
    pool_get_arr(globalGuildPool, poolIndex, guild);

    new query[256];
    
    new getGuildID[DCC_ID_SIZE];
    DCC_GetGuildId(guild[guildID], getGuildID);
    new getGuildOwner[DCC_ID_SIZE];
    DCC_GetGuildOwnerId(guild[guildID], getGuildOwner);

    mysql_format(mainDatabase, query, sizeof(query), "INSERT INTO guilds VALUES('%e', '%e', 'nil') LIMIT 1", getGuildID, getGuildOwner);
    mysql_tquery(mainDatabase, query);
    return 1;
}


updateGuild(poolIndex){
    if(!pool_has(globalGuildPool, poolIndex)) return 0;
    new guild[guildStruct];
    
    pool_get_arr(globalGuildPool, poolIndex, guild);

    new query[256];

    new getGuildID[DCC_ID_SIZE];
    DCC_GetGuildId(guild[guildID], getGuildID);
    new getGuildOwner[DCC_ID_SIZE];
    DCC_GetGuildOwnerId(guild[guildID], getGuildOwner);
    new getGuildManagerRole[DCC_ID_SIZE];
    DCC_GetRoleId(guild[guildBotManager], getGuildManagerRole);
    print(getGuildManagerRole);
    mysql_format(mainDatabase, query, sizeof(query), "UPDATE guilds SET guildOwner = '%e', guildBotManagerID = '%e' WHERE guildID = '%e' LIMIT 1", getGuildOwner, getGuildManagerRole, getGuildID);
    mysql_pquery(mainDatabase, query);
    return 1;
}

saveGuilds(){
    for(new p; p < pool_size(globalGuildPool); p++){
        updateGuild(p);
        continue;
    }
    return 1;
}

loadGuildConfig(globalGuildPoolIndex){
    task_yield(1);
    new the_guild[guildStruct];
    pool_get_arr(globalGuildPool, globalGuildPoolIndex, the_guild);
    new Map:the_map = the_guild[structConfig];
    map_set(the_map, guildLobby, 0);
    new guildInt[DCC_ID_SIZE];
    DCC_GetGuildId(the_guild[guildID], guildInt);
    await mysql_aquery(mainDatabase, sprintf("SELECT * FROM guild_config WHERE guildID = '%e' LIMIT 1", guildInt));
    if(cache_num_rows()){
        new channelInt[DCC_ID_SIZE];
        cache_get_value_name(0, "guildLobby", channelInt);
        map_set(the_map, guildLobby, _:DCC_FindChannelById(channelInt));
        await mysql_aquery(mainDatabase, sprintf("SELECT * FROM guild_roles WHERE guildID = '%e' LIMIT 1", guildInt));
        new rows = cache_num_rows();
        for(new r; r < rows; r++){
            new roleInt[DCC_ID_SIZE];
            cache_get_value_name(r, "roleID", roleInt);
            list_add(List:map_get(the_map, guildRoleAsignees), _:DCC_FindRoleById(roleInt));
        }
    }
    return 1;
}



public DCC_OnGuildCreate(DCC_Guild:guild){
    new getGuildID[DCC_ID_SIZE];
    DCC_GetGuildId(guild, getGuildID);
    printf("New guild added: %d (%s).", _:guild, getGuildID);
    new guildy[guildStruct];
    new discordIds[DCC_ID_SIZE];
    guildy[guildID] = guild;
    DCC_GetGuildOwnerId(guild, discordIds);
    guildy[guildOwner] = DCC_FindUserById(discordIds);
    guildy[ticketPool] = pool_new();
    createGuild(pool_add_arr(globalGuildPool, guildy));
    return 1;
}


public DCC_OnGuildDelete(DCC_Guild:guild){
    new getGuildID[DCC_ID_SIZE];
    DCC_GetGuildId(guild, getGuildID);
    printf("Guild removed: %d (%s).", _:guild, getGuildID);

    deleteGuild(getGuildPoolIndex(guild));
}


/*enum commandStruct{
    command_name[DCC_COMMAND_SIZE],
    desc[DCC_COMMAND_DESCRIPTION_SIZE],
    callback[60],
    bool:allow_everyone
}

static commands_arr[][commandStruct] = {
    {"setmanagerrole", "Set role that can change config", "OnManagerRoleSet", false}
}*/

loadGuildCommands(){
    list_add(guildCommandsList, _:DCC_CreateCommand("setmanagerrole", "Set role that can change configs", "OnManagerRoleSet", false));
    list_add(guildCommandsList, _:DCC_CreateCommand("setticketlobby", "Set channel for ticket issuing.", "OnTicketLobbySet", false));
    return 1;
}


getGuildPoolIndex(DCC_Guild:guild){
    if(!guild) return 0;
    for(new p; p < pool_size(globalGuildPool); p++){
        if(!pool_has(globalGuildPool, p)) continue;
        new guildArr[guildStruct];
        pool_get_arr(globalGuildPool, p, guildArr);
        if(guild == guildArr[guildID]) return p;
        else continue;
    }
    return 0;
}

IsValidRoleForGuild(DCC_Guild:guild, const role_id[]){
    new count;
    DCC_GetGuildRoleCount(guild, count);
    for(new i; i < count; i++){
        new getId[DCC_ID_SIZE];
        new DCC_Role:this_role;
        DCC_GetGuildRole(guild, i, this_role);
        DCC_GetRoleId(this_role, getId);
        if(strequal(getId, role_id, true)) return 1;
    }
    return 0;
}

DCC_Channel:IsValidChannelForGuild(DCC_Guild:guild, const channel_id[]){
    new count;
    DCC_GetGuildChannelCount(guild, count);
    for(new c; c < count; c++){
        new ChanId[DCC_ID_SIZE];
        new DCC_Channel:Chan;
        DCC_GetGuildChannel(guild, c, Chan);
        DCC_GetChannelId(Chan, ChanId);
        if(strequal(channel_id, ChanId)) return DCC_FindChannelById(channel_id);
        else continue;
    }
    return DCC_Channel:0;
}

//commands


forward OnManagerRoleSet(DCC_Interaction:interaction, DCC_User:user);
public OnManagerRoleSet(DCC_Interaction:interaction, DCC_User:user){
    new DCC_Channel:int_channel;
    new DCC_Guild:int_guild;
    DCC_GetInteractionChannel(interaction, int_channel);
    DCC_GetChannelGuild(int_channel, int_guild);
    new guildOwn[DCC_ID_SIZE];
    new userId[DCC_ID_SIZE];
    DCC_GetGuildOwnerId(int_guild, guildOwn);
    DCC_GetUserId(user, userId);
    new DCC_Embed:embed = DCC_CreateEmbed("Pawn.Tickets", "You don't have permission to run this command.");
    if(!strequal(guildOwn, userId, true))
        return DCC_SendInteractionEmbed(interaction, embed);

    new arg[DCC_ID_SIZE];
    DCC_GetInteractionContent(interaction, arg);
    
    new guildArr[guildStruct];
    new index = getGuildPoolIndex(int_guild);
    if(!pool_has(globalGuildPool, index)) DCC_SetEmbedDescription(embed, "Invalid guild.");
    pool_get_arr(globalGuildPool, index, guildArr);


    
    if(!IsValidRoleForGuild(int_guild, arg)) DCC_SetEmbedDescription(embed, "Invalid role ID for this guild!");
    else{
        guildArr[guildBotManager] = DCC_FindRoleById(arg);
        printf("%d Role ID", _:guildArr[guildBotManager]);
        if(!guildArr[guildBotManager]){
            DCC_SetEmbedDescription(embed, "Invalid role ID.");
            DCC_SendInteractionEmbed(interaction, embed);
            return 1;
        }   
        new msg[96];
        format(msg, sizeof(msg), "Selected <@&%s> as manager role.", arg);
        DCC_SetEmbedDescription(embed, msg);
        updateGuild(index);
    }

    DCC_SendInteractionEmbed(interaction, embed);
    return 1;
}

isGuildOwner(DCC_Guild:guild, DCC_User:user){
    new guildOwn[DCC_ID_SIZE];
    new userId[DCC_ID_SIZE];
    DCC_GetGuildOwnerId(guild, guildOwn);
    DCC_GetUserId(user, userId);
    if(strequal(guildOwn, userId, true)) return 1;
    else return 0;
}

// /setticketlobby [Channel ID]
forward OnTicketLobbySet(DCC_Interaction:interaction, DCC_User:user);
public OnTicketLobbySet(DCC_Interaction:interaction, DCC_User:user){
    new DCC_Channel:int_channel;
    new DCC_Guild:int_guild;
    DCC_GetInteractionChannel(interaction, int_channel);
    DCC_GetChannelGuild(int_channel, int_guild);
    new ix = getGuildPoolIndex(int_guild);
    if(!pool_has(globalGuildPool, ix)) return 1;
    new guildStr[guildStruct];
    pool_get_arr(globalGuildPool, ix, guildStr);
    new bool:has_role;
    DCC_HasGuildMemberRole(int_guild, user, guildStr[guildBotManager], has_role);
    new DCC_Embed:embed = DCC_CreateEmbed("Pawn.Tickets", "You don't have permission to run this command.");
    if(!isGuildOwner(int_guild, user) && !has_role) return DCC_SendInteractionEmbed(interaction, embed);
    new arg[DCC_ID_SIZE];
    DCC_GetInteractionContent(interaction, arg);
    
    new DCC_Channel:lobby_channel = IsValidChannelForGuild(int_guild, arg);
    
    DCC_SetEmbedDescription(embed, "Invalid channel ID.");
    if(!lobby_channel) return DCC_SendInteractionEmbed(interaction, embed);

    new Map:theGuildMap = guildStr[structConfig];
    map_set(theGuildMap, guildLobby, _:lobby_channel);
    DCC_SetEmbedDescription(embed, sprintf("Selected <#%s> as lobby for tickets.", arg));
    DCC_SendInteractionEmbed(interaction, embed);
    return 1;
}