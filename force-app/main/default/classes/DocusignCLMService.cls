public with sharing class DocusignCLMService {
    
    public class ServiceException extends Exception {}
    public static final Long MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

    public class DownloadResult {
        public String quoteId;
        public String docId;
        public Boolean isSuccess;
        public String errorMessage;
        public Blob pdfContent;
        public String fileName;
    }

    /**
     * Downloads a document content by ID from DocuSign CLM V2 API
     */
    public static DownloadResult downloadDocument(String quoteId, String docId, String accessToken) {
        DownloadResult result = new DownloadResult();
        result.quoteId = quoteId;
        result.docId = docId;
        result.isSuccess = false;

        if (String.isBlank(docId)) {
            result.errorMessage = 'Missing DocuSign Document ID (Docusign_DocId__c is null).';
            return result;
        }

        DocuSign_CLM_Setting__mdt settings = DocuSign_CLM_Setting__mdt.getInstance('Default');
        String baseUrl = settings.Base_Url__c; // e.g. https://api.na11.clm.docusign.net
        String accountId = settings.Account_Id__c;

        String endpoint = baseUrl + '/content/v2/' + accountId + '/documents/' + docId;

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/pdf');
        req.setTimeout(120000);

        try {
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Blob pdfBlob = res.getBodyAsBlob();
                if (pdfBlob.size() > MAX_FILE_SIZE_BYTES) {
                    result.errorMessage = 'File size exceeds maximum allowed limit of 5MB (Actual size: ' + 
                                          (pdfBlob.size() / (1024 * 1024)) + 'MB).';
                } else {
                    result.pdfContent = pdfBlob;
                    result.fileName = 'Signed_DocuSign_' + docId + '.pdf';
                    result.isSuccess = true;
                }
            } else if (res.getStatusCode() == 404) {
                result.errorMessage = 'Document not found or not yet available/signed in CLM.';
            } else {
                result.errorMessage = 'CLM API Error [' + res.getStatusCode() + ']: ' + res.getStatus();
            }
        } catch (Exception e) {
            result.errorMessage = 'HTTP Callout Exception: ' + e.getMessage();
        }

        return result;
    }
}