public with sharing class DocusignCLMAuth {
    
    public class AuthException extends Exception {}

    /**
     * Obtains an OAuth Access Token from DocuSign using JWT Grant.
     */
    public static String getAccessToken() {
        DocuSign_CLM_Setting__mdt settings = DocuSign_CLM_Setting__mdt.getInstance('Default');
        if (settings == null) {
            throw new AuthException('DocuSign CLM Custom Metadata settings missing.');
        }

        String iss = settings.Integration_Key__c;
        String sub = settings.User_Id__c;
        String aud = 'account.docusign.com'; // Use account-d.docusign.com for Developer Sandbox

        Auth.JWT jwt = new Auth.JWT();
        jwt.setSub(sub);
        jwt.setIss(iss);
        jwt.setAud(aud);
        
        // Additional claims required by DocuSign
        Map<String, Object> additionalClaims = new Map<String, Object>();
        additionalClaims.put('scope', 'signature extended');
        jwt.setAdditionalClaims(additionalClaims);

        // Certificate Name stored in Salesforce Certificate and Key Management
        String certDevName = 'DocuSign_CLM_JWT_Cert';
        
        try {
            Auth.JWS jws = new Auth.JWS(jwt, certDevName);
            String tokenUrl = 'https://' + aud + '/oauth/token';
            
            Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(tokenUrl, jws);
            String response = bearer.getAccessToken();
            return response;
        } catch (Exception e) {
            throw new AuthException('Failed to generate JWT Token: ' + e.getMessage());
        }
    }
}