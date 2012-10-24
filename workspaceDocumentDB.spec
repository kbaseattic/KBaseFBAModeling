/*
=head1 workspaceDocumentDB

API for accessing and writing documents objects to a workspace.

*/
module workspaceDocumentDB {
	typedef int bool;
	typedef string workspace_id;
	typedef string object_type;
	typedef string object_id;
	typedef string permission;
	typedef string username;
	typedef string timestamp;
	typedef structure { 
       int version;
    } ObjectData;
    typedef structure { 
       int version;
    } WorkspaceData;
	typedef tuple<object_id id,object_type type,timestamp moddate,int instance,string command,username lastmodifier,username owner> object_metadata;
	typedef tuple<workspace_id id,username owner,timestamp moddate,int objects,permission user_permission,permission global_permission> workspace_metadata;
	
	/*Object management routines*/
    funcdef save_object(object_id id,object_type type,ObjectData data,workspace_id workspace) returns (bool success);
    funcdef delete_object(object_id id,object_type type,ObjectData data,workspace_id workspace) returns (bool success);
    funcdef get_object(object_id id,object_type type,workspace_id workspace) returns (ObjectData data);    
    funcdef revert_object(object_id id,object_type type,workspace_id workspace) returns (bool success);
    funcdef copy_object(object_id new_id,workspace_id new_workspace,object_id source_id,object_type type,workspace_id source_workspace) returns (bool success);
    funcdef move_object(object_id new_id,workspace_id new_workspace,object_id source_id,object_type type,workspace_id source_workspace) returns (bool success);
    funcdef has_object(object_id id,object_type type,workspace_id workspace) returns (bool object_present);
    
    /*Workspace management routines*/
    funcdef create_workspace(workspace_id name,permission default_permission) returns (bool success);
    funcdef clone_workspace(workspace_id new_workspace,workspace_id current_workspace,permission default_permission) returns (bool success);
    funcdef list_workspaces() returns (list<workspace_metadata> workspaces);
    typedef structure { 
       string type;
    } list_workspace_objects_options;
    funcdef list_workspace_objects(workspace_id workspace,list_workspace_objects_options options) returns (list<object_metadata> objects);
    funcdef set_global_workspace_permissions(permission new_permission,workspace_id workspace) returns (bool success);
    funcdef set_workspace_permissions(list<username> users,permission new_permission,workspace_id workspace) returns (bool success);

};
