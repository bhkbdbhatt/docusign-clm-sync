public with sharing class BulkDownloadController {

    public class ProcessResult {
        @AuraEnabled public Integer totalProcessed = 0;
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public Boolean isAsync = false;
        @AuraEnabled public List<String> errorMessages = new List<String>();
    }

    @AuraEnabled
    public static ProcessResult executeBulkDownload(List<Id> quoteIds) {
        ProcessResult res = new ProcessResult();
        if (quoteIds == null || quoteIds.isEmpty()) {
            return res;
        }

        res.totalProcessed = quoteIds.size();

        // If batch size > 20, route off to Queueable chain to prevent timeout and stay under 200 callout limit
        if (quoteIds.size() > 20) {
            System.enqueueJob(new BulkDownloadQueueable(quoteIds));
            res.isAsync = true;
            return res;
        }

        return processSyncDownload(quoteIds);
    }

    public static ProcessResult processSyncDownload(List<Id> quoteIds) {
        ProcessResult result = new ProcessResult();
        result.totalProcessed = quoteIds.size();

        List<Quote> quotes = [
            SELECT Id, Name, Docusign_DocId__c 
            FROM Quote 
            WHERE Id IN :quoteIds
            WITH USER_MODE
        ];

        String token;
        try {
            token = DocusignCLMAuth.getAccessToken();
        } catch (Exception e) {
            result.errorCount = quoteIds.size();
            result.errorMessages.add('Authentication Failed: ' + e.getMessage());
            return result;
        }

        List<ContentVersion> cvToInsert = new List<ContentVersion>();
        Map<String, Id> docIdToQuoteIdMap = new Map<String, Id>();
        List<Quote> quotesToUpdate = new List<Quote>();

        for (Quote q : quotes) {
            if (String.isBlank(q.Docusign_DocId__c)) {
                result.errorCount++;
                result.errorMessages.add('Quote ' + q.Name + ': Missing Docusign_DocId__c.');
                continue;
            }

            DocusignCLMService.DownloadResult res = DocusignCLMService.downloadDocument(q.Id, q.Docusign_DocId__c, token);

            if (res.isSuccess) {
                ContentVersion cv = new ContentVersion();
                cv.Title = res.fileName;
                cv.PathOnClient = res.fileName;
                cv.VersionData = res.pdfContent;
                cv.IsMajorVersion = true;
                cvToInsert.add(cv);

                docIdToQuoteIdMap.put(res.fileName, q.Id);

                quotesToUpdate.add(new Quote(
                    Id = q.Id,
                    Last_Download__c = System.now()
                ));
                result.successCount++;
            } else {
                result.errorCount++;
                result.errorMessages.add('Quote ' + q.Name + ': ' + res.errorMessage);
            }
        }

        if (!cvToInsert.isEmpty()) {
            insert as user cvToInsert;

            // Fetch newly generated ContentDocumentIds
            List<ContentVersion> insertedCVs = [
                SELECT Id, Title, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id IN :cvToInsert
                WITH USER_MODE
            ];

            List<ContentDocumentLink> cdlToInsert = new List<ContentDocumentLink>();
            for (ContentVersion cv : insertedCVs) {
                Id targetQuoteId = docIdToQuoteIdMap.get(cv.Title);
                if (targetQuoteId != null) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = cv.ContentDocumentId;
                    cdl.LinkedEntityId = targetQuoteId;
                    cdl.ShareType = 'V'; // Viewer permission
                    cdl.Visibility = 'AllUsers';
                    cdlToInsert.add(cdl);
                }
            }

            if (!cdlToInsert.isEmpty()) {
                insert as user cdlToInsert;
            }

            if (!quotesToUpdate.isEmpty()) {
                update as user quotesToUpdate;
            }
        }

        return result;
    }
}