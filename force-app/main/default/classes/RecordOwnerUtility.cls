/**
* @author Ben Repak
* @date 2021-02-17
*
* @description Utility class that can be used to retreive random active users based on profile, group, queue, or role.
* Helpful for assigning record ownership to any user from a particular group in a pseudo round-robin style.
*/

public with sharing class RecordOwnerUtility {
    /*******************************************************************************************************
    * @description when set to true, all queried user records will be stored in a map (cachedUserSearchMap) to 
    . When set to false, only the first record returned will be stored in the map. 
    */
    public static Boolean cacheAllUserRecords = true;
    
    /*******************************************************************************************************
    * @description allows setting query limits on returned user records
    */
    public static Integer defaultQueryRecordLimit = 200;

    /*******************************************************************************************************
    * @description allows querying of all accessible fields on the user object as needed. If set to false, 
    * only Id, FirstName, LastName, Name, UserName are returned
    */
    public static Boolean queryAllUserFields = false;

    /*******************************************************************************************************
    * @description caches user fields for select statement if queryAllUserFields is true
    */
    private static String cachedUserFields;

    /*******************************************************************************************************
    * @description input parameter of specific component to be queried (e.g. if querying profiles, 
    * this value might be "Standard User")
    */
    private static String cachedFromWhereNameOrId;

    /*******************************************************************************************************
    * @description input parameter of component type to be queried. 
    * Acceptable value are: group, profile, role, user
    */
    private static String cachedFromWhereType;

    /*******************************************************************************************************
    * @description holds users returned for a specific component type / name query to avoid unnecessary SOQL 
    */
    private static Map<String, List<User>> cachedUserSearchMap = new Map<String, List<User>>();


    /*******************************************************************************************************
    * @description returns a random user from the specified group/queue
    * @param fromWhereNameOrId component id or DeveloperName of the group/queue to be queried
    * @return a random user record the the list of records queried 
    * @example
     * public with sharing class MyClass {
     *   
     *   public void myPublicMethod(List<Contact> contactsToUpdate){
     *       for(Contact c : contactsToUpdate){
     *           User u = RecordOwnerUtility.getRandomUserByGroupOrQueue('My_Public_Group');
     *           c.OwnerId = u.id
     *       }
     *       update contactsToUpdate;
     *   }
     * }
     */
    public static User getRandomUserByGroupOrQueue(String fromWhereNameOrId){
        return getRandomUser('group', fromWhereNameOrId);
    }


    /*******************************************************************************************************
    * @description returns a random user from the specified profile
    * @param fromWhereNameOrId component id or Name of the profile to be queried
    * @return a random user record the the list of records queried 
    * @example
     * public with sharing class MyClass {
     *   
     *   public void myPublicMethod(List<Contact> contactsToUpdate){
     *       for(Contact c : contactsToUpdate){
     *           User u = RecordOwnerUtility.getRandomUserByProfile('My Custom Profile');
     *           c.OwnerId = u.id
     *       }
     *       update contactsToUpdate;
     *   }
     * }
     */
    public static User getRandomUserByProfile(String fromWhereNameOrId){
        return getRandomUser('profile', fromWhereNameOrId);
    }


    /*******************************************************************************************************
    * @description returns a random user from the specified role
    * @param fromWhereNameOrId component id or DeveloperName of the role to be queried
    * @return a random user record the the list of records queried 
    * @example
     * public with sharing class MyClass {
     *   
     *   public void myPublicMethod(List<Contact> contactsToUpdate){
     *       for(Contact c : contactsToUpdate){
     *           User u = RecordOwnerUtility.getRandomUserByRole('My_Custom_Role');
     *           c.OwnerId = u.id
     *       }
     *       update contactsToUpdate;
     *   }
     * }
     */
    public static User getRandomUserByRole(String fromWhereNameOrId){
        return getRandomUser('role', fromWhereNameOrId);
    }


    /*******************************************************************************************************
    * @description returns a random user from the specified role
    * @param fromWhereNameOrId full name of the user to be queried
    * @return user record where the full name is equal to  fromWhereNameOrId input param
    * @example
     * public with sharing class MyClass {
     *   
     *   public void myPublicMethod(List<Contact> contactsToUpdate){
     *       for(Contact c : contactsToUpdate){
     *           User u = RecordOwnerUtility.getUserByFullName('Taylor Swift');
     *           c.OwnerId = u.id
     *       }
     *       update contactsToUpdate;
     *   }
     * }
     */
    public static User getUserByFullName(String fromWhereNameOrId){
        return getRandomUser('user', fromWhereNameOrId);
    }


    /*******************************************************************************************************
    * @description main handler method for this class to retrieve/query users and return a random user from the desired component type / name key
    * @param fromWhereType type of component to return random user from (group, profile, role, user name)
    * @param fromWhereNameOrId name/dev name or ID of fromWhereType (e.g. My Custom Profile, My_Custom_Role, My_Custom_Group)
    * @return a User record
    */
    private static User getRandomUser(String fromWhereType, String fromWhereNameOrId){
        validateQueryLimit();
        User u;
        String queryString;
        List<User> users;
        cachedFromWhereNameOrId = fromWhereNameOrId;
        cachedFromWhereType = fromWhereType;
         
        // get users from cache or query
        users = getUsers();

        // select random users from list
        u = selectRandomUser(users);

        // if after checking cache and executing query there still isn't a user, fall back to currentUser 
        if(u == null){
            u = getCurrentUser();
        }
        return u;
    }


    /*******************************************************************************************************
    * @description build dyanmic query string based on the type of component to query
    * @return dynamic user query string 
    */
    private static string buildSingleTypeQueryString(String fromWhereType){
        String selectString = 'Id, FirstName, LastName, Name, UserName';
        String whereString;
        String queryString;
       
        if(queryAllUserFields == true && cachedUserFields == null){
            cachedUserFields = getUserFields();
        } 
        if(queryAllUserFields == true && cachedUserFields != null) {
            selectString = cachedUserFields;
        }

        switch on fromWhereType.toLowerCase(){
            when 'group' {
                whereString = 'Id IN (SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName = :cachedFromWhereNameOrId OR GroupId = :cachedFromWhereNameOrId) LIMIT ' + defaultQueryRecordLimit;
            }
            when 'user'{
                whereString = '(Name =:cachedFromWhereNameOrId OR Id =:cachedFromWhereNameOrId) LIMIT 1';
            }
            when 'profile'{
                whereString = 'ProfileId  IN (SELECT Id FROM Profile WHERE name = :cachedFromWhereNameOrId or Id =:cachedFromWhereNameOrId) LIMIT ' + defaultQueryRecordLimit;
            }
            when 'role'{
                whereString  = 'UserRoleId IN (SELECT Id FROM UserRole WHERE DeveloperName = :cachedFromWhereNameOrId or Id =:cachedFromWhereNameOrId) LIMIT ' + defaultQueryRecordLimit;
            }
        }
        // system.debug('queryString --> ' + queryString);
        if(whereString != null){
            queryString = 'SELECT ' + selectString + ' FROM User WHERE isActive = TRUE AND ' + whereString;
        }
        system.debug('select string --> ' + selectString);
        return queryString;
    }


    /*******************************************************************************************************
    * @description ensures that defaultQueryRecordLimit is within acceptable bounds
    */
    private static void validateQueryLimit(){
        if(defaultQueryRecordLimit < 1 || defaultQueryRecordLimit >= 50000){
            defaultQueryRecordLimit = 200;
        }
    }


    /*******************************************************************************************************
    * @description handler to retrieve usrs from map if the key exists, or else perform the query
    * @return a list of users from a map retrieval or query
    */
    private static List<User> getUsers(){
        List<User> users  = new List<User>();
        users = getCachedUsers();
        if(users.size() == 0 && Limits.getQueries() < 100) {
            String dynamicQuery = buildSingleTypeQueryString(cachedFromWhereType);
            users = Database.query(dynamicQuery);
            updatedCachedUserListMap(users);
        }
        return users;
    }


    /*******************************************************************************************************
    * @description retrieves cached users based on the mapKey (see getUserSearchMapKey)
    * @return list of users from map or a new user list
    */
    private static List<User> getCachedUsers(){
        String mapKey = getUserSearchMapKey();
        List<User> users;
        if(cachedUserSearchMap.get(mapKey) != null){
            users = cachedUserSearchMap.get(mapKey);
           //  u = selectRandomUser(Users);
        } else {
            users = new List<User>();
        }
        return users;
    }


    /*******************************************************************************************************
    * @description adds user records as values to the cachedUserSearchMap
    * @param userResults list of users to add to the map
    */
    private static void updatedCachedUserListMap(List<User> userResults){
        String mapKey = getUserSearchMapKey();
        // if not cacheing all users by mapKey, only add one randomly selected user to the list
        if(cacheAllUserRecords == false){
            User randomUser = selectRandomUser(userResults);
            userResults.clear();
            userResults.add(randomUser);
        }
        for(User u : userResults){
            if(cachedUserSearchMap.containsKey(mapKey)) {
                List<User> users = cachedUserSearchMap.get(mapKey);
                users.add(u);
            } else {
                cachedUserSearchMap.put(mapKey, new List<User> {u});
            }
        }
    }


    /*******************************************************************************************************
    * @description creates a key to be used in the cachedUserSearchMap. Key is based on the component type and
    * component name to be searched. E.G. when performing RecordOwnerUtility.getRandomUserByProfile('my custom profile'), 
    * the key would becoe "profile my custom profile"
    */
    private static string getUserSearchMapKey(){
        return cachedFromWhereType+cachedFromWhereNameOrId;
    }


    /*******************************************************************************************************
    * @description returns basic information about the running user
    * @return a user record with basic field values from the running user
    */
    private static User getCurrentUser() {
        User u = new User();
        u.id = UserInfo.getUserId();
        u.username = UserInfo.getUserName(); 
        u.firstName = UserInfo.getFirstName();
        u.lastName = UserInfo.getLastName();
       return u;
    }


    /*******************************************************************************************************
    * @description in the input list is > 0, a user is returned from a random index. Otherwise current user returned
    * @param users list of users to randomly select user from
    */
     private static User selectRandomUser(List<User> users) {
        Integer listSize = users.size();
        if(listSize == 1){
            return users[0];
        }else if(listSize > 1) {
           Integer randomIndex = getRandomInteger(listSize);
            return users[randomIndex];
        } else {
            return getCurrentUser();
        }
     }


    /*******************************************************************************************************
    * @description returns a random integer between zero and the upper limit input param
    * @param upperLimit upper limit for random number generation
    */
    private static integer getRandomInteger(Integer upperLimit){
        Double randomNumber = Math.random() * upperLimit;
        Integer randomIndex = randomNumber.intValue();
        return randomIndex;
    }


    /*******************************************************************************************************
    * @description retrieves all fields accessible to the running user from the User object
    */
    private static string getUserFields(){
        List<String> userFieldsList = new List<String>();
        for(Schema.SObjectField fld : Schema.SObjectType.User.fields.getMap().values()) {
            // skip field if user cannot access
            if(!fld.getDescribe().isAccessible()){
                continue;
            }
            string fieldString = fld.getDescribe().getName();
            userFieldsList.add(fieldString);
        }
        String selectStringfields = String.join(userFieldsList, ', ');
        return selectStringfields;
    }


    /*******************************************************************************************************
    * @description inner class used with invocable method.
    */
    public class RecordOwnerRequest{
        @InvocableVariable (label='Enable Multi User Query Cache' required=true)
        public boolean cacheAllUserRecords;

        @InvocableVariable (label='User Query Type(Profile, Group, Role, or User)' required=true)
        public string fromWhereType;

        @InvocableVariable (label='Name of component to query (e.g. My Custom User Profile' required=true)
        public string fromWhereNameOrId;

        @InvocableVariable (label='Query Limit # Override' required=false)
        public integer defaultQueryRecordLimit;

        @InvocableVariable (label='Query All User Fields' required=false)
        public boolean queryAllUserFields = false;

    }


    /*******************************************************************************************************
    * @description inner class used with invocable method.
    */
    public class RecordOwnerResponse{
        @InvocableVariable
        public User randomUser;
    }


    /*******************************************************************************************************
    * @description incovable method used in flows
    * @param requests a list of RecordOwnerRequest records
    * @return a list of RecordOwnerResponse records, each with a User property
    */
    @InvocableMethod (label='Get Random User' description='Returns the list of random users from specified profiles, roles, or groups.')
    public static List<RecordOwnerResponse> getRandomUser(List<RecordOwnerRequest> requests){
        List<RecordOwnerResponse> responses = new List<RecordOwnerResponse>();
        for(RecordOwnerRequest request : requests){
            if(request.defaultQueryRecordLimit != null){
                defaultQueryRecordLimit = request.defaultQueryRecordLimit;
            }
            if(request.cacheAllUserRecords != null){
                cacheAllUserRecords = request.cacheAllUserRecords;
            }
            queryAllUserFields = request.queryAllUserFields;

            RecordOwnerResponse response = new RecordOwnerResponse();
            response.randomUser = getRandomUser(request.fromWhereType, request.fromWhereNameOrId);
            responses.add(response);
        }
        return responses;
    }


}