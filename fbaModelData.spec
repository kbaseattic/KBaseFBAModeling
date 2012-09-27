/*
=head1 fbaModelData

Data access library for fbaModel services. This API is meant for
interanl use only. Do not distribute or expose publically.

*/
module fbaModelData {
    typedef int Bool; 
    typedef string Ref;
    typedef string Username;
    typedef string UUID;
    typedef string Data;

    typedef list<UUID> UUIDs;
    typedef list<Username> Usernames;
    typedef structure { 
       UUID uuid;
       Username owner;
       string type;
       string alias;
    } Alias;

    typedef list<Alias> Aliases;
    
    typedef structure {
        UUIDs object;
        list<UUIDs> objectParents;
    } AncestorGraph;

    typedef structure {
        UUIDs object;
        list<UUIDs> objectChildren;
    } DescendantGraph;

    typedef structure {
        Bool is_merge;
        Bool schema_update;
    } SaveConf;

    typedef structure {
        Bool keep_data;
    } DeleteConf;

    funcdef has_data            ( Ref ref ) returns (Bool existence);
    funcdef get_data            ( Ref ref ) returns (Data data);
    funcdef save_data           ( Ref ref, Data data, SaveConf config ) returns (Bool success); 

    funcdef get_aliases         ( Alias query ) returns (Aliases aliases);
    funcdef update_alias        ( Ref ref, UUID uuid ) returns (Bool success);
    funcdef add_viewer          ( Ref ref, Username viewer ) returns (Bool success);
    funcdef remove_viewer       ( Ref ref, Username viewer ) returns (Bool success);
    funcdef set_public          ( Ref ref, Bool public ) returns (Bool success);
    funcdef alias_owner         ( Ref ref ) returns (Username owner);
    funcdef alias_public        ( Ref ref ) returns (Bool public);
    funcdef alias_viewers       ( Ref ref ) returns (Usernames viewers);

    funcdef ancestors           ( Ref ref ) returns (UUIDs ancestors);
    funcdef ancestor_graph      ( Ref ref ) returns (AncestorGraph graph);
    funcdef descendants         ( Ref ref ) returns (UUIDs descendants);
    funcdef descendant_graph    ( Ref ref ) returns (DescendantGraph graph);

    funcdef init_database       () returns Bool success;
    funcdef delete_database     (DeleteConf config) returns (Bool success);
};
