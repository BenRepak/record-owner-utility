@isTest
public with sharing class RecordOwnerUtility_TEST {


    // create group and role for later use in testing
    @TestSetup
    private static void makeData(){
        Group grp = new Group();
        grp.name = 'Test Group';
        grp.developername = 'Test_Group';
        grp.type = 'Regular';
        insert grp;

        UserRole usrRole= new UserRole(); 
        usrRole.name = 'Test User Role';
        usrRole.developerName = 'Test_User_Role';
        insert usrRole;
    }


    // getRandomUserByGroupOrQueue
    @isTest
    private static void testRandomUserByGroup(){
        String groupName = 'Test Group';
        // used for random assignment from utility class
        User randomUser;
        
        // used to add to desired asset
        User targetUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();
        insert targetUser;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        // get group id
        Group grp = [SELECT Id FROM Group WHERE Name = :groupName LIMIT 1][0];

        // create group member
        GroupMember gm = new GroupMember();
        gm.groupId = grp.id;
        gm.UserOrGroupId = targetUser.id;
        insert gm;

        Test.startTest();
        System.runAs(runningUser){
            RecordOwnerUtility.queryAllUserFields = true;
            randomUser = RecordOwnerUtility.getRandomUserByGroupOrQueue('Test_Group');
        }
        Test.stopTest();

        System.assertEquals(targetUser.id,randomUser.id,'Expect user added to group and random user to be the same');
    }


    // getRandomUserByProfile 
    @isTest
    private static void testRandomUserByProfile(){
        String profileName = 'Read Only';
      
        // used for random assignment from utility class
        User randomUser;
        
        // used to add to desired asset
        User targetUser = TestDataFactory_User.start()
        .overrideProfile(profileName)
        .create();
        insert targetUser;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        Test.startTest();
        System.runAs(runningUser){
            randomUser = RecordOwnerUtility.getRandomUserByProfile(profileName);
        }
        Test.stopTest();

        System.assertEquals(targetUser.id,randomUser.id,'Expect target user and random user to be the same');
    }


    // getRandomUserByRole 
    @isTest
    private static void testRandomUserByRole(){
        String roleName = 'Test_User_Role';
      
        // used for random assignment from utility class
        User randomUser;
        
        // used to add to desired asset
        User targetUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .overrideRole('Test User Role')
        .create();
        insert targetUser;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        Test.startTest();
        System.runAs(runningUser){
            randomUser = RecordOwnerUtility.getRandomUserByRole(roleName);
        }
        Test.stopTest();

        System.assertEquals(targetUser.id,RandomUser.id,'Expect target user and random user to be the same');
    }


    // getUserByFullName
    @isTest
    private static void testRandomUserByFullName(){
        // used for random assignment from utility class
        User randomUser;
        
        // used to add to desired asset
        User targetUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .setFirstName('Taylor')
        .setLastName('Swift')
        .create();
        insert targetUser;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        Test.startTest();
        System.runAs(runningUser){
            randomUser = RecordOwnerUtility.getUserByFullName('Taylor Swift');
        }
        Test.stopTest();

        System.assertEquals(targetUser.id,randomUser.id,'Expect target user and running user to be the same due search by name');
    }


    // testing fallback to current user if there is no user found
    @isTest
    private static void testRandomUserFallbackToRunningUser(){
        // used for random assignment from utility class
        User randomUser;
        
        // used to add to desired asset
        User targetUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();
        insert targetUser;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        String groupName = 'Test Group';
    
        Test.startTest();
        System.runAs(runningUser){
            randomUser = RecordOwnerUtility.getRandomUserByGroupOrQueue(groupName);
        }
        Test.stopTest();

        System.assertEquals(runningUser.id,randomUser.id,'Expect target user and running user to be the same due to no members in group');
    }


    // test cacheing of avoid multiple queries when utility called multiple times
    @isTest
    private static void testRandomUserByProfile_Bulk(){
        String profileName = 'Read Only';
      
        // used for random assignment from utility class
        User randomUser;
        
        // create 10 target users
        List<User> usersToInsert = new List<User>();
        integer floor = 0;
        integer ceiling = 9;
        while(floor < 10) {
            User targetUser = TestDataFactory_User.start()
            .overrideProfile(profileName)
            .create();
            usersToInsert.add(targetUser);
            floor++;
        }
        insert usersToInsert;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        Integer queryCount = 0;

        Test.startTest();
        System.runAs(runningUser){
            floor = 0;
            ceiling = 9;
            while(floor < 10) {
                randomUser = RecordOwnerUtility.getRandomUserByProfile(profileName);
                floor++;
            }
        }
        queryCount = Limits.getQueries();
        Test.stopTest();

        System.assertEquals(1,queryCount,'Expect 1 soql query despire 10 separate calls to method');
    }

      // getRandomUser invocable
    @isTest
    private static void testInvocableByProfileName(){
        String profileName = 'Read Only';
      
        // used for random assignment from utility class
        User randomUser;
        
        // create 10 target users
        List<User> usersToInsert = new List<User>();
        integer floor = 0;
        integer ceiling = 9;
        while(floor < 10) {
            User targetUser = TestDataFactory_User.start()
            .overrideProfile(profileName)
            .create();
            usersToInsert.add(targetUser);
            floor++;
        }
        insert usersToInsert;

        // used to run method
        User runningUser = TestDataFactory_User.start()
        .overrideProfile('Standard User')
        .create();

        Integer queryCount = 0;
        
        Test.startTest();
        List<RecordOwnerUtility.RecordOwnerRequest> requests = new  List<RecordOwnerUtility.RecordOwnerRequest>();
        List<RecordOwnerUtility.RecordOwnerResponse> responses = new  List<RecordOwnerUtility.RecordOwnerResponse>();
        floor = 0;
        ceiling = 9;
        while(floor < 10) {
            RecordOwnerUtility.RecordOwnerRequest request = new RecordOwnerUtility.RecordOwnerRequest();
            request.fromWhereType = 'profile';
            request.fromWhereNameOrId = profileName;
            request.cacheAllUserRecords = true;
            requests.add(request);
            floor++;
        }
        
        responses = RecordOwnerUtility.getRandomUser(requests);
        queryCount = Limits.getQueries();

        System.assertEquals(1,queryCount,'Expect 1 soql query despire 10 separate calls to method');
    }


    



    
}
