public with sharing class BulkDownloadQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> quoteIds;
    private static final Integer BATCH_SIZE = 20;

    public BulkDownloadQueueable(List<Id> quoteIds) {
        this.quoteIds = quoteIds;
    }

    public void execute(QueueableContext context) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return;
        }

        List<Id> currentBatch = new List<Id>();
        List<Id> remainingQuoteIds = new List<Id>();

        for (Integer i = 0; i < quoteIds.size(); i++) {
            if (i < BATCH_SIZE) {
                currentBatch.add(quoteIds[i]);
            } else {
                remainingQuoteIds.add(quoteIds[i]);
            }
        }

        // Process current chunk of 20
        BulkDownloadController.processSyncDownload(currentBatch);

        // Chain execution if remaining items exist
        if (!remainingQuoteIds.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new BulkDownloadQueueable(remainingQuoteIds));
        }
    }
}