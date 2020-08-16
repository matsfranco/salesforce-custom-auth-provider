global with sharing class GithubRegistrationHandler extends Auth.AuthProviderPluginClass {

    private String customMetadataTypeApiName = 'GitHubProvider__mdt';
    public  String redirectUrl; 
    private String key;
    private String secret;
    private String authUrl;  
    private String accessTokenUrl; 
    private String userInfoUrl; 
    private String scope;
    
    global String getCustomMetadataType(){
        return customMetadataTypeApiName;
    }
    
    /* Step 1 */
    /*
    Go to 3rd Party Login Page and type user and password to get access
    Allow or Deny
    Returns PageReference with reference to the redirect URL
    The String urlToRedirect is aligned with GitHub Auth API
    Send all necessary values
    */
    global PageReference initiate(Map<string,string> authProviderConfiguration, String stateToPropagate) { 
    
        key         = authProviderConfiguration.get('ConsumerKey__c');
        authUrl     = authProviderConfiguration.get('AuthURL__c');
        scope       = authProviderConfiguration.get('Scope__c');
        redirectUrl = authProviderConfiguration.get('CallbackURL__c');
        String urlToRedirect = authUrl+'?client_id='+key+'&redirect_uri='+redirectUrl+'&scope='+scope+
                               '&state='+stateToPropagate+'&allow_signup=false';
                               
        PageReference pageRef = new PageReference(urlToRedirect);                    
        return pageRef; 
    } 
    
    /* Step 2 */
    /*  code comes from GitHub - AAuth Code
        state - SUCCESS when authorized
        Access Token + Callback URL
    */
    global Auth.AuthProviderTokenResponse handleCallback(Map<string,string> authProviderConfiguration, Auth.AuthProviderCallbackState state ) { 
        
        // This will contain an optional accessToken and refreshToken 
        key = authProviderConfiguration.get('ConsumerKey__c'); 
        secret = authProviderConfiguration.get('ConsumerSecret__c'); 
        accessTokenUrl = authProviderConfiguration.get('TokenURL__c'); 
        redirectUrl = authProviderConfiguration.get('CallbackURL__c');
        
        Map<String,String> queryParams = state.queryParameters; 
        
        String code = queryParams.get('code'); 
        String sfdcState = queryParams.get('state'); 
        
        /* Create the access token on GitHub Site*/
        HttpRequest req = new HttpRequest(); 
        String requestBody = 'client_id='+key+'&client_secret='+secret+'&code='+code
                             +'&redirect_uri='+redirectUrl+'&state='+sfdcState;
        req.setEndpoint(accessTokenUrl); 
        req.setHeader('Accept','application/json'); 
        req.setMethod('POST'); 
        req.setBody(requestBody);
        Http http = new Http(); 
        
        HTTPResponse res = http.send(req); 

        /* Response with Auth content */
        String responseBody = res.getBody(); 
        /* Wrap Inner Class*/
        GitHubWrapper wrapper = (GitHubWrapper)System.JSON.deserialize(responseBody, GitHubWrapper.class);
        
        return new Auth.AuthProviderTokenResponse('GithubRegistrationHandler', wrapper.access_token, 'refreshToken', sfdcState); 
    } 
   
    global Auth.UserData getUserInfo(Map<string,string> authProviderConfiguration, Auth.AuthProviderTokenResponse response) { 
        userInfoUrl = authProviderConfiguration.get('UserInfoURL__c');
        
        HttpRequest req = new HttpRequest(); 
        
        req.setEndpoint(userInfoUrl); 
        req.setHeader('Content-Type','application/json'); 
        req.setMethod('GET'); 
        req.setHeader('Authorization', 'Bearer '+response.oauthToken);
        Http http = new Http(); 
        HTTPResponse res = http.send(req); 
        
        String responseBody = res.getBody();
        
        GithubUserWrapper userInfo = (GithubUserWrapper)System.JSON.deserialize(responseBody, GithubUserWrapper.class);
        
        List<String> nameInfo = userInfo.name.split(' ');
        
        /* Mandatory*/
        Map<String,String> attributeMap = new Map<String,String>{'noauth' => 'NOUTHS'};
        
        Auth.UserData userdata = new Auth.UserData(userInfo.login, nameInfo.get(0), nameInfo.get(1), 
                 userInfo.name, userInfo.email, userInfo.url, userInfo.login, 'en_US', 'Github', null , attributeMap );
        
        System.debug('### userInfo '+userInfo);
        
        /*
            UserData(String identifier, String firstName, String lastName, String fullName, String email, 
                     String link, String userName, String locale, String provider, String siteLoginUrl, 
                     Map<String,String> attributeMap
            )
        */
        
        return userdata;
    } 
    
    
    public class GitHubWrapper {
        public String access_token; 
        public String scope;    
        public String token_type;
        
    }
    
    public class GithubUserWrapper{
        public String login;   
        public Integer id;  
        public String url;  
        public String html_url; 
        public String name; 
        public String company;  
        public String blog; 
        public String location;
        public String email;  
    }

}