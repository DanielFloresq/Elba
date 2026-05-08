({
    openEmailModal: function(component, event, helper) {
        const recordId = component.get("v.recordId");
        const documentIds = event.getParam("documentIds") || [];

        if (!documentIds || documentIds.length === 0) {
            console.warn("Nenhum documento selecionado");
            return;
        }

        const quickActionAPI = component.find("quickActionAPI");

        quickActionAPI.selectAction({ actionName: "Case.SendEmail" }) // Certifica-te que é o nome da tua ação
            .then(() => {
                // Preenche o campo "Related To" com o Case atual
                quickActionAPI.setActionFieldValue({ fieldName: "whatId", fieldValue: recordId });

                // Preenche os anexos
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