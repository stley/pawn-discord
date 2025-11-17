new Pool:globalGuildPool;



enum guildStruct{
    DCC_Guild:guildID,
    DCC_User:guildOwner,
    DCC_Role:guildBotManager,
    Pool:ticketPool
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
        printf("Guild row %d added at global pool (index %d).", row, pool_add_arr(globalGuildPool, guild));
        guild[ticketPool] = pool_new();
        loaded++;
        break;
    }
    printf("%d guilds loaded from database.", loaded);
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


getGuildPoolIndex(DCC_Guild:guild){
    for(new p; p < pool_size(globalGuildPool); p++){
        if(!pool_has(globalGuildPool, p)) continue;
        new guildy[guildStruct];
        pool_get_arr(globalGuildPool, p, guildy);
        if(guild == guildy[guildID]) return p;
        else continue;
    }
    return -1;
}