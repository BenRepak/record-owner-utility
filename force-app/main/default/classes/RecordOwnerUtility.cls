public with sharing class RecordOwnerUtility {
    public static Boolean cacheAllUserRecords = true;
    public static Integer defaultQueryRecordLimit = 200;
    public static Boolean queryAllUserFields = false;
    private static String cachedUserFields;
    private static String cachedFromWhereNameOrId;
    private static String cachedFromWhereType;
    private static Map<String, List<User>> cachedUserSearchMap = new Map<String, List<User>>();


    public static User getRandomUserByGroupOrQueue(String fromWhereNameOrId){
        return getRandomUser('group', fromWhereNameOrId);
    }


    public static User getRandomUserByProfile(String fromWhereNameOrId){
        return getRandomUser('profile', fromWhereNameOrId);
    }


    public static User getRandomUserByRole(String fromWhereNameOrId){
        return getRandomUser('role', fromWhereNameOrId);
    }


    public static User getUserByFullName(String fromWhereNameOrId){
        return getRandomUser('user', fromWhereNameOrId);
    }


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


    private static void validateQueryLimit(){
        if(defaultQueryRecordLimit < 1 || defaultQueryRecordLimit >= 50000){
            defaultQueryRecordLimit = 200;
        }
    }


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


    private static string getUserSearchMapKey(){
        return cachedFromWhereType+cachedFromWhereNameOrId;
    }


    private static User getCurrentUser() {
        User u = new User();
        u.id = UserInfo.getUserId();
        u.username = UserInfo.getUserName(); 
        u.firstName = UserInfo.getFirstName();
        u.lastName = UserInfo.getLastName();
       return u;
    }

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


    private static integer getRandomInteger(Integer upperLimit){
        Double randomNumber = Math.random() * upperLimit;
        Integer randomIndex = randomNumber.intValue();
        return randomIndex;
    }


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

    public class RecordOwnerResponse{
        @InvocableVariable
        public User randomUser;
    }


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