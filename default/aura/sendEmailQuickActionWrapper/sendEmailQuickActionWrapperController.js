({
    openEmailModal: function(component, event, helper) {
        const documentIds = event.getParam ? event.getParam("documentIds") : event.documentIds || [];
        const recordId = component.get("v.recordId");

        if (!documentIds.length) {
            console.warn("Nenhum documento selecionado");
            return;
        }

        const quickActionAPI = component.find("quickActionAPI");

        quickActionAPI.selectAction({ actionName: "Case.SendEmail" })
            .then(() => {
                quickActionAPI.setActionFieldValue({ fieldName: "whatId", fieldValue: recordId });

                const attachments = documentIds.map(id => ({
                    documentId: id,
                    attachmentType: 'ContentDocument'
                }));

                quickActionAPI.setActionFieldValue({ fieldName: "attachments", fieldValue: attachments });

                console.log('Modal de email aberto com anexos:', attachments);
            })
            .catch(error => console.error('Erro ao abrir QuickAction Email:', error));
    }
})