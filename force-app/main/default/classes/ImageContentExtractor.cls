public class ImageContentExtractor
{
    static string apiUrl='https://api.einstein.ai/v2/vision/ocr';
    static string token='';
    
    @InvocableMethod
    public static void getImageText(List<string> records)
    {
        List<Id> recodId = new List<Id>();
        List<Case> cases = [SELECT Id FROM Case WHERE Id in :records];
        Case record;
        for (Case c : cases) {
            recodId.add(c.Id);
            record=c;
        }
        
        List<ContentDocumentLink> links=[SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink where LinkedEntityId=:recodId];
        Set<Id> ids=new Set<Id>();
        for(ContentDocumentLink link:links)
        {
            ids.add(link.ContentDocumentId);
        }
        
        List<ContentVersion> versions=[SELECT VersionData,Title,ContentDocumentId,FileExtension FROM ContentVersion WHERE ContentDocumentId = :ids AND IsLatest = true];
        
        List<ContentDistribution> cdts=[select ContentDocumentId,DistributionPublicUrl,ContentDownloadURL from ContentDistribution where ContentDocumentId =:ids];
        
        Map<String, String> contentList= new Map <String, String>();  
        for(ContentDistribution cdt:cdts)
        {
            contentList.put(cdt.ContentDocumentId, cdt.ContentDownloadURL);     
        }
        
        List<OCRTemplateMapping__c> mappings=[Select MinX__c,MaxX__c,MinY__c,MaxY__c,Field__c from OCRTemplateMapping__c where name='Form1'];
        for(ContentVersion attach:versions)
        {           
            String imageUrl=contentList.get(attach.ContentDocumentId);
            system.debug('imageUrl'+imageUrl);
            if(string.isNotBlank(imageUrl))
            {           
                token=new EinsteinController().getAccessToken();
                string response=EinsteinOCR.extractText(imageUrl, token, 'OCRModel');
                
                EinsteinOCRReponse plateRespone=EinsteinOCRReponse.parse(response);
                if(plateRespone.probabilities!=null)
                {
                    for(OCRTemplateMapping__c mapping:mappings)
                    {   
                        string value='';
                        for(EinsteinOCRReponse.Probability prob:plateRespone.probabilities)
                        {
                            EinsteinOCRReponse.BoundingBox  bpx=prob.boundingBox;
                            if(bpx.minY>=mapping.MinY__c && bpx.maxY<=mapping.MaxY__c && bpx.minX>=mapping.MinX__c)
                            {
                               value+=prob.label+' ';
                            }
                        }
                        record.put(mapping.Field__c,value);
                    }
                }
                update record;
            }
        }
        
    }
}