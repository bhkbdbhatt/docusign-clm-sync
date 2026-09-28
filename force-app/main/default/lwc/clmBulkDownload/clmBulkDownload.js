import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import executeBulkDownload from '@salesforce/apex/BulkDownloadController.executeBulkDownload';

export default class ClmBulkDownload extends LightningElement {
    @api ids = []; // Auto-populated when invoked as a List View Action
    @track isProcessing = false;
    @track isFinished = false;
    @track progressValue = 0;
    @track resultSummary = {};

    get selectedIds() {
        return Array.isArray(this.ids) ? this.ids : [];
    }

    handleStartDownload() {
        if (!this.selectedIds || this.selectedIds.length === 0) {
            this.showToast('Warning', 'Please select at least one Quote record.', 'warning');
            return;
        }

        this.isProcessing = true;
        this.progressValue = 25;

        executeBulkDownload({ quoteIds: this.selectedIds })
            .then(result => {
                this.progressValue = 100;
                this.isProcessing = false;
                this.isFinished = true;
                this.resultSummary = result;

                if (result.isAsync) {
                    this.showToast(
                        'Job Enqueued',
                        'Large batch detected (>20 records). The download is running in the background via Queueable Apex.',
                        'info'
                    );
                } else if (result.errorCount === 0) {
                    this.showToast('Success', `Successfully attached ${result.successCount} PDFs.`, 'success');
                } else {
                    this.showToast('Completed with Warnings', 'Some documents failed to download.', 'warning');
                }
            })
            .catch(error => {
                this.isProcessing = false;
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            });
    }

    closeAction() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}