
#define mysql_host  "localhost"
#define mysql_user  "root"
#define mysql_pass  ""
#define mysql_database  "pawn-tickets"


new MySQL:mainDatabase;

forward databaseInit();
forward databaseExit();


databaseInit(){
    new MySQLOpt:options = mysql_init_options();
    mysql_set_option(options, AUTO_RECONNECT, true);
    mysql_set_option(options, POOL_SIZE, 8);
    mainDatabase = mysql_connect(mysql_host, mysql_user, mysql_pass, mysql_database, options);
    if(mysql_errno(mainDatabase)){
        new err[96];
        mysql_error(err);
        printf("Failed to connect to MySQL database: %s.", err);
    }
    mysql_log(ALL);
    return 1;
}

databaseExit(){
    if(mainDatabase) mysql_close(mainDatabase);
    return 1;
}

public OnQueryError(errorid, const error[], const callback[], const query[], MySQL:handle){
    printf("Failed to execute query for callback \"%s\": %s", callback, error);
    printf("Query DUMP:\n%s", query);
    return 1;
}