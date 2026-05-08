({
    handleDocumentsSelected: function(component, event, helper) {
        const selectedIds = event.getParam("documentIds") || [];
        console.log('IDs recebidos do LWC:', selectedIds);
        component.set("v.selectedDocumentIds", selectedIds);

        // Chama QuickAction direto ao receber IDs
        helper.openEmailModal(component, selectedIds);
    }
})