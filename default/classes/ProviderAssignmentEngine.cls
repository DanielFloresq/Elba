/**
 * @description       : Dynamic provider assignment engine for Encargo allocation.
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 30-04-2026
 * @last modified by  : Daniel Flores
**/
public with sharing class ProviderAssignmentEngine {

    private static final Map<String, String> countryCodesMap = new Map<String, String>{
        'PT' => 'Portugal',
        'ESP' => 'Espanha'
    };

    // Classe auxiliar para receber parâmetros do Flow
    public class FlowRequestWithMode {
        @InvocableVariable(required=true)
        public Id encargoId;
        @InvocableVariable(required=true)
        public Boolean isManual;
    }

    public class AssignInfo {
        public String reason;
        public String description;
    }

    /**
    * @description Assign providers to an Encargo (Order) in manual or automatic mode.
    * @author Afonso Duque | 03-02-2026
    * @param  encargoId
    * @param  config
    * @param  isManual
    * @return AssignmentResult
    **/
    @AuraEnabled(cacheable=false)
    public static AssignmentResult getAssignments(Id encargoId, AssignmentConfig config, Boolean isManual) {

        AssignmentResult result = assignEncargo(encargoId, config, isManual);

        if(result.success){
            if (isManual) {
                List<Id> providerOrder = new List<Id>();
                Map<String, AssignInfo> providersInfo = new Map<String, AssignInfo>();
                for (PAEFlowProviderSnapshot snapshot : result.manualResults) {
                    //system.debug(snapshot.stepByStepDescription);
                    if (snapshot != null && snapshot.providerId != null) {
                        providerOrder.add(snapshot.providerId);

                        AssignInfo info = new AssignInfo();
                        info.reason = snapshot.reason;
                        info.description = result.stepByStepDescription;
                        providersInfo.put(snapshot.providerId, info);
                    }
                }
                result.providers = getProviders(providerOrder, providersInfo);
            } else {
                system.debug(result.stepByStepDescription);
                Map<String, AssignInfo> providersInfo = new Map<String, AssignInfo>();
                if (result.providerId != null) {
                    AssignInfo info = new AssignInfo();
                    info.reason = result.reason;
                    info.description = result.stepByStepDescription;
                    providersInfo.put(result.providerId, info);
                }
                result.providers = getProviders(new List<Id>{ result.providerId }, providersInfo);
            }
        }

        return result;
    }

    /**
    * @description Retrieve provider details based on a map of provider IDs and motives.
    * @author Afonso Duque | 03-02-2026
    * @param  providersInfo
    * @return List<Provider>
    **/
    public static List<Provider> getProviders(Map<String, AssignInfo> providersInfo){

        List<Provider> providers = new List<Provider>();

        List<Account> accounts = [SELECT Id, Name, ShippingAddress, (SELECT Value__c, Type__c FROM AccountPhones__r ORDER BY CreatedDate DESC) FROM Account WHERE Id IN :providersInfo.keySet()];
        for(Account acc : accounts){
            Set<String> phoneList = new Set<String>();
            Set<String> emailList = new Set<String>();
            for(AccountInformation__c info : acc.AccountPhones__r){
                if(info.Type__c == 'Phone' && !phoneList.contains(info.Value__c) && phoneList.size() < 4){
                    phoneList.add(info.Value__c);
                }
                if(info.Type__c == 'Email' && !emailList.contains(info.Value__c) && emailList.size() < 2){
                    emailList.add(info.Value__c);
                }
            }

            String phones = !phoneList.isEmpty() ? String.join(phoneList, ' | ') : '';
            String emails = !emailList.isEmpty() ? String.join(emailList, ' | ') : '';
            String shippingAddress = setShippingAddress(acc.ShippingAddress);

            AssignInfo info = providersInfo.get(acc.Id);
            providers.add(new Provider(acc.Id, acc.Name, info.reason, phones, emails, shippingAddress, info.description));
        }

        return providers;
    }

    /**
    * @description Retrieve provider details preserving the caller-defined order.
    * @param  providerOrder Order of provider IDs to return
    * @param  providersInfo Map of provider IDs to motives
    * @return List<Provider>
    **/
    public static List<Provider> getProviders(List<Id> providerOrder, Map<String, AssignInfo> providersInfo) {
        List<Provider> providers = new List<Provider>();

        if (providerOrder != null && !providerOrder.isEmpty()) {
            Map<Id, Account> accountById = new Map<Id, Account>([
                SELECT Id, Name, ShippingAddress,
                    (SELECT Value__c, Type__c FROM AccountPhones__r ORDER BY CreatedDate DESC)
                FROM Account
                WHERE Id IN :providerOrder
            ]);

            for (Id providerId : providerOrder) {
                if (providerId != null) {
                    Account acc = accountById.get(providerId);
                    if (acc != null) {
                        Set<String> phoneList = new Set<String>();
                        Set<String> emailList = new Set<String>();
                        for (AccountInformation__c info : acc.AccountPhones__r) {
                            if (info.Type__c == 'Phone' && !phoneList.contains(info.Value__c) && phoneList.size() < 4) {
                                phoneList.add(info.Value__c);
                            }
                            if (info.Type__c == 'Email' && !emailList.contains(info.Value__c) && emailList.size() < 2) {
                                emailList.add(info.Value__c);
                            }
                        }

                        String phones = !phoneList.isEmpty() ? String.join(phoneList, ' | ') : '';
                        String emails = !emailList.isEmpty() ? String.join(emailList, ' | ') : '';
                        String shippingAddress = setShippingAddress(acc.ShippingAddress);
                        AssignInfo info = providersInfo != null ? providersInfo.get(providerId) : null;
                        providers.add(new Provider(acc.Id, acc.Name, info.reason, phones, emails, shippingAddress, info.description));
                    }
                }
            }
        }

        return providers;
    }

    /**
    * @description Format the shipping address from the Address object into a single string, including street, postal code, city, state, and country. The country code is converted to the full country name using a predefined map. If any part of the address is missing, it is skipped in the final string.
    * @author Afonso Duque | 11-02-2026
    * @param  address
    * @return String
    **/
    public static String setShippingAddress(System.Address address){
        String shippingAddress = '';
        if(address != null) {
            shippingAddress += String.isNotBlank(address.street) ? address.street + ' ' : '';
            shippingAddress += String.isNotBlank(address.postalCode) ? address.postalCode + ', ' : '';
            shippingAddress += String.isNotBlank(address.city) ? address.city + ' ' : '';
            shippingAddress += String.isNotBlank(address.state) ? address.state + ', ' : '';
            shippingAddress += (String.isNotBlank(address.country) ? (countryCodesMap.containsKey(address.country) ? countryCodesMap.get(address.country) : address.country) : '');
        }
        return shippingAddress;
    }

    /**
    * @description Retrieve all active provider guilds from the custom metadata type DependenceProviderTypeGuild__mdt.
    * @author Afonso Duque | 05-02-2026
    * @return List<DependenceProviderTypeGuild__mdt>
    **/
    @AuraEnabled(cacheable=true)
    public static List<DependenceProviderTypeGuild__mdt> getAllDependentProviderGuilds() {
        List<DependenceProviderTypeGuild__mdt> guilds = [SELECT ProviderType__c, Guild__c, Urgency__c FROM DependenceProviderTypeGuild__mdt];
        return guilds;
    }

    /**
    * @description Create or update an Order record based on the provided JSON string. If isAssignment is true, it updates the Order for assignment; otherwise, it creates a new Order with the given details. It also updates the related Case status if necessary.
    * @author Afonso Duque | 11-02-2026
    * @param orderInfoJSON
    * @param isAssignment
    * @return String
    **/
    @AuraEnabled
    public static String createOrder(String orderInfoJSON, Boolean isAssignment) {

        Order recordOrder;
        OrderInfo orderInfo = (OrderInfo) JSON.deserialize(orderInfoJSON, OrderInfo.class);
        List<Case> recordCase = [SELECT Id, Status, AccountId, Contact.Name, MailingInformation__PostalCode__s,ContactId FROM Case WHERE Id = :orderInfo.caseId LIMIT 1];

        if(!recordCase.isEmpty()){

            String stakeHolderId = (recordCase[0].Contact != null ? getStakeHolderId(recordCase[0].Id, recordCase[0].Contact.Name) : null);

            if(isAssignment){

                recordOrder = [SELECT CaseNumber__c, AccountId, Account.Name, Guild__c FROM Order WHERE Id = :orderInfo.id LIMIT 1];

                if(recordOrder.AccountId != orderInfo.providerId){

                    List<Account> accounts = [SELECT Id, RecordType.DeveloperName FROM Account WHERE Id = :orderInfo.providerId LIMIT 1];
                    recordOrder.AccountId = orderInfo.providerId;

                    if(accounts[0].RecordType.DeveloperName == 'Supplier'){
                        recordOrder.Status = 'FirstContact';
                        if((recordCase[0].Status == 'Opening')){
                            recordCase[0].Status = 'In Progress';
                            update recordCase[0];
                        }
                    }

                    upsert recordOrder;
                    updateOrderServices(recordOrder, stakeHolderId, recordOrder.Account.Name);
                }

            } else {

                recordOrder = new Order(
                    Id = orderInfo.id,
                    Type = orderInfo.type,
                    ProviderType__c = orderInfo.providerType,
                    Guild__c = String.join(orderInfo.guild, ';'),
                    Urgent__c = orderInfo.urgent,
                    CaseNumber__c = orderInfo.caseId,
                    AccountId = recordCase[0].AccountId,
                    Status = 'Order Assignment',
                    Description = orderInfo.description,
                    EffectiveDate = Date.today(),
                    BillingPostalCode = recordCase[0].MailingInformation__PostalCode__s,
                    BillToContactId = recordCase[0].ContactId
                );

                upsert recordOrder;
                createNewServices(recordOrder, recordCase[0].Id, stakeHolderId);
            }

        }
        return recordOrder != null && recordOrder.Id != null ? recordOrder.Id : orderInfo.id;
    }

    /**
    * @description Create an AlgorithmOutcomes__c record to log the step-by-step description of the provider assignment process for a given Order. This method is intended to be called after the assignment process to store the outcome details for future reference and analysis.
    * @author Afonso Duque | 11-02-2026
    * @param stepByStep
    * @param assignmentType
    * @param recordId
    **/
    @AuraEnabled
    public static void createAlgorithmOutcome(String stepByStep, String assignmentType, Id recordId) {

        if(recordId != null && String.isNotBlank(stepByStep) && String.isNotBlank(assignmentType)){
            AlgorithmOutcomes__c algo = new AlgorithmOutcomes__c();
            algo.Order__c = recordId;
            algo.Type__c = assignmentType;
            algo.StepbyStepDescription__c = stepByStep;
            insert algo;
        }

    }

    /**
    * @description Create new Service__c records for a given Order and Case. This method deletes any existing services for the Order and creates new ones based on the provided Order and Case details.
    * @author Afonso Duque | 11-02-2026
    * @param newOrder
    * @param caseId
    * @param stakeHolderId
    **/
    public static void createNewServices(Order newOrder, String caseId, String stakeHolderId) {

        // Because of going back in the LWC we are deleting the old records creted before creating new ones, to avoid duplicates.
        List<Service__c> services = [SELECT Id FROM Service__c WHERE Order__c = :newOrder.Id];
        if(!services.isEmpty()){
            delete services;
        }

        List<Service__c> newServices = PelayoWebServiceController.mapServicesFromEncargo(newOrder, caseId, stakeHolderId);
        if(!newServices.isEmpty()){
            insert newServices;
        }
    }

    /**
    * @description Retrieve the Stakeholder ID based on the given Case ID and Contact Name. This method queries the Stakeholders__c object to find a matching record for the provided Case ID and Contact Name, returning the Stakeholder ID if found. If no matching record is found or if the Contact Name is blank, it returns null.
    * @author Afonso Duque | 11-02-2026
    * @param  caseId
    * @param  contactName
    * @return String
    **/
    public static String getStakeHolderId(String caseId, String contactName) {
        String stakeHolderId = null;
        if(String.isNotBlank(contactName)){
            List<Stakeholders__c> stakeholders = [SELECT Id, Name FROM Stakeholders__c WHERE Case__c = :caseId AND Name =:contactName LIMIT 1];
            if(!stakeholders.isEmpty()){
                stakeHolderId = stakeholders[0].Id;
            }
        }
        return stakeHolderId;
    }

    /**
    * @description Update the StartDate__c and Status__c fields of all Service__c records related to a given Order. This method is intended to be called after an Order has been assigned to a provider, setting the start date to the current date and updating the status to 'Assigned' for all related services.
    * @author Afonso Duque | 11-02-2026
    * @param recordOrder
    **/
    public static void updateOrderServices(Order recordOrder, String stakeholderId, String oldProvider) {

        List<Service__c> servicesToUpdate = [SELECT Id, Order__c, Claim__c, Status__c, StartDate__c, Type__c, Description__c FROM Service__c WHERE Order__c = :recordOrder.Id AND Status__c != 'Cancelled'];
        List<Service__c> servicesToInsert = new List<Service__c>();

        List<String> orderGuilds = new List<String>();
        if (recordOrder.Guild__c != null) {
            orderGuilds = recordOrder.Guild__c.split(';');
        }

        for (Service__c service : servicesToUpdate) {

            if(orderGuilds.contains(service.Type__c)){
                if(service.Status__c == 'Apertura'){
                    service.StartDate__c = Date.valueOf(System.today());
                    service.Status__c = 'Apertura';
                } else {
                    Service__c newService = cloneProviderService(service, stakeholderId);
                    servicesToInsert.add(newService);

                    service.Description__c = 'Servicio cancelado porque estaba relacionado con el Prestador: ' + oldProvider;
                    service.Status__c = 'Cancelado/Anulado';
                }
                // Remove the value of the service.Type__c from orderGuilds
                if (orderGuilds.contains(service.Type__c)) {
                    orderGuilds.remove(orderGuilds.indexOf(service.Type__c));
                }

            } else {
                service.Description__c = 'Servicio cancelado porque estaba relacionado con el Prestador: ' + oldProvider;
                service.Status__c = 'Cancelado/Anulado';
            }
        }

        if(!orderGuilds.isEmpty()){
            Id recordTypeId = Schema.SObjectType.Service__c.getRecordTypeInfosByDeveloperName().get('Multiguild').getRecordTypeId();
            for (String newGuild : orderGuilds) {
                Service__c newService = setNewProviderService(recordOrder, newGuild, stakeholderId, recordTypeId);
                servicesToInsert.add(newService);
            }
    }

        if (!servicesToUpdate.isEmpty()) {
            update servicesToUpdate;
        }
        if (!servicesToInsert.isEmpty()) {
            insert servicesToInsert;
        }
    }

    /**
    * @description Create a new Service__c record for a given old service and stakeholder ID. This method clones the old service record, sets the Stakeholder__c field to the provided stakeholder ID, updates the StartDate__c to the current date, and sets the Status__c to 'Assigned'. The new service record is returned without being inserted into the database, allowing for further processing before insertion.
    * @author Afonso Duque | 11-02-2026
    * @param  oldService
    * @param  stakeholderId
    * @return Service__c
    **/
    public static Service__c cloneProviderService(Service__c oldService, String stakeholderId) {
        Service__c newService = oldService.clone(false, false, false, false);
        newService.Stakeholder__c = stakeholderId;
        newService.StartDate__c = Date.valueOf(System.today());
        newService.Status__c = 'Apertura';
        newService.Description__c = '';
        return newService;
    }

    /**
    * @description Create a new Service__c record for a given Order, new guild, stakeholder ID, and record type ID. This method initializes a new Service__c record with the provided details, setting the Claim__c to the Order's CaseNumber__c, the Order__c to the Order's Id, the Type__c to the new guild, the Status__c to 'Assigned', and the StartDate__c to the current date. The Stakeholder__c and RecordTypeId fields are also set based on the provided parameters. The new service record is returned without being inserted into the database, allowing for further processing before insertion.
    * @author Afonso Duque | 13-02-2026
    * @param  recordOrder
    * @param  newGuild
    * @param  stakeholderId
    * @param  recordTypeId
    * @return Service__c
    **/
    public static Service__c setNewProviderService(Order recordOrder, String newGuild, String stakeholderId, String recordTypeId) {
        Service__c newService = new Service__c(
            Claim__c = recordOrder.CaseNumber__c,
            Order__c = recordOrder.Id,
            Type__c = newGuild,
            Status__c = 'Apertura',
            StartDate__c = Date.valueOf(System.today()),
            Stakeholder__c = stakeholderId,
            RecordTypeId = recordTypeId
        );
        return newService;
    }

    // Overload para compatibilidade retroativa: assume isManual = false
    /**
    * @description Assign providers to an Encargo (Order) in automatic mode. This method is an overload of the main assignEncargo method, defaulting to automatic mode by setting isManual to false. It validates the input parameters, loads the Encargo and potential providers, evaluates them based on defined criteria, and returns the best eligible provider along with the reasoning behind the selection.
    * @author Afonso Duque | 11-02-2026
    * @param encargoId
    * @param config
    * @return AssignmentResult
    **/
    public static AssignmentResult assignEncargo(Id encargoId, AssignmentConfig config) {
        return assignEncargo(encargoId, config, false);
    }

    // =========================================================
    // 1) ENTRADAS PRINCIPAIS
    // =========================================================
    // Esta classe recebe um Encargo (Order) e escolhe o melhor
    // fornecedor (Account) com base em regras objetivas.
    // NÃO atualiza contadores nem grava no encargo; isso é feito
    // fora (Flow), conforme pedido.

    // Método principal: escolhe e atribui o melhor fornecedor a um encargo.
    // Faz validações, carrega dados, avalia, aplica a atribuição e devolve o resultado.

    /**
    * @description Assign providers to an Encargo (Order) with an option for manual or automatic mode. This method validates input parameters, loads the Encargo and potential providers, evaluates them based on defined criteria, and returns the best eligible provider along with the reasoning behind the selection.
    * @author Afonso Duque | 11-02-2026
    * @param encargoId
    * @param config
    * @param isManual
    * @return AssignmentResult
    **/
    @AuraEnabled
    public static AssignmentResult assignEncargo(Id encargoId, AssignmentConfig config, Boolean isManual) {
        if (config == null) {
            config = new AssignmentConfig();
        }
        if (encargoId == null) {
            return buildErrorResult('El EncargoId es obligatorio.');
        }

        SObject encargo = loadEncargo(encargoId, config);
        if (encargo == null) {
            return buildErrorResult('Encargo no encontrado.');
        }

        // Resolve coverage limit (Order/Case) once to avoid per-provider queries.
        resolveCoverageLimit(encargo, config);

        List<SObject> providers = loadProviders(encargo, config);
        if (providers.isEmpty()) {
            AssignmentResult result = buildErrorResult('No se encontraron proveedores para evaluar.');
            // Importante para modo automático: explicar por que não houve atribuição.
            String encargoPostal = getString(encargo, config.encargoPostalCodeField);
            result.stepbyStepDescription = 'No se encontraron proveedores para evaluar.' +
                ' Filtros aplicados: activeFilter=' + String.valueOf(config.activeFilter) +
                ', activeField=' + String.valueOf(config.activeField) +
                ', prefilterByPostalCode=' + String.valueOf(config.prefilterByPostalCode) +
                ', encargoPostal=' + String.valueOf(encargoPostal) +
                ', providerPostalCodesField=' + String.valueOf(config.providerPostalCodesField) +
                ', postalPrefixMinLength=' + String.valueOf(config.postalPrefixMinLength) + '.';
            return result;
        }

        // SupplierGuild__c é usado apenas para excluir características (Type) que estejam de férias.
        // Só carrega os Type com Status__c='Active' e apenas os que podem excluir este encargo.
        Set<String> requiredGuildTypes = getMultiPicklist(encargo, config.encargoTypeField);
        loadActiveSupplierGuildTypes(providers, requiredGuildTypes, config);

        List<ProviderSnapshot> evaluations = evaluate(encargo, providers, config);
        if (isManual == true) {
            // Modo manual: devolver top 5 (mesmo não elegíveis), com explicação
            List<ProviderSnapshot> top5 = new List<ProviderSnapshot>();
            // Ordenar por score decrescente (Apex não suporta lambda, usar sort manual)
            List<ProviderSnapshot> sorted = new List<ProviderSnapshot>();
            sorted.addAll(evaluations);
            sorted.sort(new ProviderSnapshotScoreDesc());
            Integer count = 0;
            Boolean highlightedBest = false;
            for (ProviderSnapshot snap : sorted) {
                if (count >= 5) break;
                // Só mostrar saturados (CAPACITY) ou elegíveis; nunca outros ineligíveis
                if (!snap.eligible) {
                    if (snap.failureStage != String.valueOf(EvaluationStage.CAPACITY)) {
                        continue;
                    }
                }
                // Se não elegível por saturação, explicar
                if (!snap.eligible && snap.failureStage == String.valueOf(EvaluationStage.CAPACITY)) {
                    CapacityState cap = computeCapacity(snap.provider, config);
                    Boolean dailyFull = (cap.dailyAssigned + 1 > cap.dailyCap);
                    Decimal allowedOpenCap = cap.openCap + cap.openPriorityAllowance;
                    Boolean openFull = (cap.openAssigned + 1 > allowedOpenCap);
                    List<String> motivos = new List<String>();
                    // Capacidade diária
                    if (cap.dailyCap == 0) {
                        motivos.add('La capacidad diaria del proveedor es cero.');
                    } else if (dailyFull) {
                        motivos.add('Alcanzó el límite diario: ' + String.valueOf(cap.dailyAssigned) + ' de ' + String.valueOf(cap.dailyCap) + ' servicios.');
                    }
                    // Capacidade aberta
                    if (allowedOpenCap == 0) {
                        motivos.add('La capacidad máxima de servicios abiertos es cero.');
                    } else if (openFull) {
                        motivos.add('Alcanzó el límite de servicios abiertos: ' + String.valueOf(cap.openAssigned) + ' de ' + String.valueOf(allowedOpenCap) + '.');
                    }
                    if (cap.openPriorityAllowance != null && cap.openPriorityAllowance > 0) {
                        if (openFull) {
                            motivos.add('Incluso con prioridad de capacidad (+' + formatDecimal(cap.openPriorityAllowance, 0) + '), excedería ' + formatLoad(cap.openAssigned + 1, allowedOpenCap) + '. Aun así se mantiene entre los más recomendables si acepta superar el límite.');
                        } else {
                            motivos.add('Puede recibir hasta +' + formatDecimal(cap.openPriorityAllowance, 0) + ' encargos adicionales (CapacityPriority__c).');
                        }
                    }
                    // Fatores de sobrecarga
                    Decimal overloadFactor = getApplicableFactor(snap.provider, config.overloadWindows, config.overloadFactorField, config.defaultOverloadFactor);
                    Decimal overPendingFactor = getApplicableFactor(snap.provider, config.overPendingWindows, config.overPendingFactorField, config.defaultOverPendingFactor);
                    if (overloadFactor != null && overloadFactor != 1) {
                        motivos.add('Factor de sobrecarga aplicado: ' + String.valueOf(overloadFactor) + '.');
                    }
                    if (overPendingFactor != null && overPendingFactor != 1) {
                        motivos.add('Factor de sobrependiente aplicado: ' + String.valueOf(overPendingFactor) + '.');
                    }
                    // Dados ausentes
                    if (cap.dailyCap == null || cap.openCap == null) {
                        motivos.add('Datos de capacidad ausentes o inválidos.');
                    }
                    // Prioridade até saturação
                    Boolean priority = getBoolean(snap.provider, config.priorityUntilSaturationField);
                    if (priority == true && (!cap.canAssign)) {
                        motivos.add('El proveedor es prioritario hasta saturación, pero ya está saturado.');
                    }
                    if (motivos.isEmpty()) {
                        motivos.add('Motivo de capacidad no especificado.');
                    }
                    snap.reason = 'Esta cuenta no fue recomendada por saturación: ' + String.join(motivos, ' ');
                } else if (snap.eligible) {
                    String detail = !String.isBlank(snap.reason) ? snap.reason : 'Sin detalles.';
                    if (!highlightedBest) {
                        snap.reason = 'Más recomendable: ' + detail;
                        highlightedBest = true;
                    } else {
                        snap.reason = 'Recomendable: ' + detail;
                    }
                }
                top5.add(snap);
                count++;
            }


            AssignmentResult result = new AssignmentResult();
            result.success = true;
            result.manualResults = toFlowSnapshots(top5);
            // Adiciona todos os avaliados para visualização (accounts + reasons)
            result.allEvaluatedProviders = toFlowSnapshots(evaluations);
            result.manualFeedback = buildManualFeedback(evaluations);
            result.stepbyStepDescription = buildStepByStepDescription(evaluations);
            return result;
        } else {
            // Modo automático: só 1 fornecedor elegível
            ProviderSnapshot best = selectBest(evaluations);
            if (best == null) {
                AssignmentResult result = buildErrorResult('No se encontró ningún proveedor elegible.');
                // Mesmo quando falha, devolver o resumo por fases para diagnóstico.
                result.stepbyStepDescription = buildStepByStepDescription(evaluations);
                return result;
            }
            AssignmentResult result = buildSuccessResult(best.providerId, best.score);
            result.warnings.addAll(best.warnings);
            result.reason = !String.isBlank(best.selectionDetails) ? best.selectionDetails : best.reason;
            result.stepbyStepDescription = buildStepByStepDescription(evaluations);
            debug(config, best, 'SELECTED: ' + result.reason);
            return result;
        }
    }

    /*@AuraEnabled
    public static AssignmentResult assignEncargo(Id encargoId, AssignmentConfig config, Boolean isManual) {

        AssignmentResult result = new AssignmentResult();
        config = (config == null ? new AssignmentConfig() : config);

        if(encargoId != null){

            SObject encargo = loadEncargo(encargoId, config);

            if(encargo != null){

                // Resolve coverage limit (Order/Case) once to avoid per-provider queries.
                resolveCoverageLimit(encargo, config);
                List<SObject> providers = loadProviders(encargo, config);

                if(!providers.isEmpty()){

                    // Guilds do fornecedor podem vir de um objeto relacionado (SupplierGuild__c).
                    // Carrega uma vez para todos os fornecedores, evitando query por fornecedor.
                    loadActiveSupplierGuildTypes(providers, config);

                    List<ProviderSnapshot> evaluations = evaluate(encargo, providers, config);
                    if (isManual) {
                        // Modo manual: devolver top 5 (mesmo não elegíveis), com explicação
                        List<ProviderSnapshot> top5 = new List<ProviderSnapshot>();
                        // Ordenar por score decrescente (Apex não suporta lambda, usar sort manual)
                        List<ProviderSnapshot> sorted = new List<ProviderSnapshot>();
                        sorted.addAll(evaluations);
                        sorted.sort(new ProviderSnapshotScoreDesc());
                        Integer count = 0;
                        Boolean highlightedBest = false;
                        for (ProviderSnapshot snap : sorted) {
                            if (count >= 5) break;
                            // Só mostrar saturados ou elegíveis; nunca Type/Guild mismatch
                            if (!(!snap.eligible && snap.failureStage == String.valueOf(EvaluationStage.TYPE_GUILD))) {
                                // Se não elegível por saturação, explicar
                                if (!snap.eligible && snap.failureStage == String.valueOf(EvaluationStage.CAPACITY)) {
                                    CapacityState cap = computeCapacity(snap.provider, config);
                                    Boolean dailyFull = (cap.dailyAssigned + 1 > cap.dailyCap);
                                    Decimal allowedOpenCap = cap.openCap + cap.openPriorityAllowance;
                                    Boolean openFull = (cap.openAssigned + 1 > allowedOpenCap);
                                    List<String> motivos = new List<String>();
                                    // Capacidade diária
                                    if (cap.dailyCap == 0) {
                                        motivos.add('Capacidade diária do fornecedor é zero.');
                                    } else if (dailyFull) {
                                        motivos.add('Atingiu o limite diário: ' + String.valueOf(cap.dailyAssigned) + ' de ' + String.valueOf(cap.dailyCap) + ' serviços.');
                                    }
                                    // Capacidade aberta
                                    if (allowedOpenCap == 0) {
                                        motivos.add('Capacidade máxima de serviços em aberto é zero.');
                                    } else if (openFull) {
                                        motivos.add('Atingiu o limite de serviços em aberto: ' + String.valueOf(cap.openAssigned) + ' de ' + String.valueOf(allowedOpenCap) + '.');
                                    }
                                    if (cap.openPriorityAllowance != null && cap.openPriorityAllowance > 0) {
                                        if (openFull) {
                                            motivos.add('Mesmo com prioridade de capacidade (+' + formatDecimal(cap.openPriorityAllowance, 0) + '), ultrapassaria ' + formatLoad(cap.openAssigned + 1, allowedOpenCap) + '. Ainda assim permanece entre os mais recomendáveis se aceitar exceder o limite.');
                                        } else {
                                            motivos.add('Pode receber até +' + formatDecimal(cap.openPriorityAllowance, 0) + ' encargos adicionais (CapacityPriority__c).');
                                        }
                                    }
                                    // Fatores de sobrecarga
                                    Decimal overloadFactor = getApplicableFactor(snap.provider, config.overloadWindows, config.overloadFactorField, config.defaultOverloadFactor);
                                    Decimal overPendingFactor = getApplicableFactor(snap.provider, config.overPendingWindows, config.overPendingFactorField, config.defaultOverPendingFactor);
                                    if (overloadFactor != null && overloadFactor != 1) {
                                        motivos.add('Fator de sobrecarga aplicado: ' + String.valueOf(overloadFactor) + '.');
                                    }
                                    if (overPendingFactor != null && overPendingFactor != 1) {
                                        motivos.add('Fator de sobrependente aplicado: ' + String.valueOf(overPendingFactor) + '.');
                                    }
                                    // Dados ausentes
                                    if (cap.dailyCap == null || cap.openCap == null) {
                                        motivos.add('Dados de capacidade ausentes ou inválidos.');
                                    }
                                    // Prioridade até saturação
                                    Boolean priority = getBoolean(snap.provider, config.priorityUntilSaturationField);
                                    if (priority == true && (!cap.canAssign)) {
                                        motivos.add('Fornecedor é prioritário até saturação, mas já está saturado.');
                                    }
                                    if (motivos.isEmpty()) {
                                        motivos.add('Motivo de capacidade não especificado.');
                                    }
                                    snap.reason = 'Esta conta não foi recomendada por saturação: ' + String.join(motivos, ' ');
                                } else if (snap.eligible) {
                                    String detail = !String.isBlank(snap.reason) ? snap.reason : 'Sem detalhes.';
                                    if (!highlightedBest) {
                                        snap.reason = 'Mais recomendável: ' + detail;
                                        highlightedBest = true;
                                    } else {
                                        snap.reason = 'Recomendável: ' + detail;
                                    }
                                }
                                top5.add(snap);
                                count++;
                            }
                        }

                        result.success = true;
                        result.manualResults = toFlowSnapshots(top5);
                        // Adiciona todos os avaliados para visualização (accounts + reasons)
                        result.allEvaluatedProviders = toFlowSnapshots(evaluations);
                        result.manualFeedback = buildManualFeedback(evaluations);

                    } else {
                        // Modo automático: só 1 fornecedor elegível
                        ProviderSnapshot best = selectBest(evaluations);
                        if(best != null){
                            result = buildSuccessResult(best.providerId, best.score);
                            result.warnings.addAll(best.warnings);
                            result.reason = !String.isBlank(best.selectionDetails) ? best.selectionDetails : best.reason;
                            result.stepbyStepDescription = buildStepByStepDescription(evaluations);
                            debug(config, best, 'SELECTED: ' + result.reason);
                        } else {
                            result = buildErrorResult('No eligible provider found.');
                        }
                    }
                } else {
                    result = buildErrorResult('No providers found for evaluation.');
                }
            } else {
                result = buildErrorResult('Encargo not found.');
            }
        } else {
            result = buildErrorResult('EncargoId is required.');
        }

        return result;
    }*/

    // Entrada alternativa para LWC/API: recebe JSON com overrides de configuração.
    // Útil para testar cenários diferentes sem alterar código.

    /**
    * @description Assign providers to an Encargo (Order) with configuration overrides provided in JSON format. This method allows testing different scenarios without changing the code.
    * @author Afonso Duque | 11-02-2026
    * @param encargoId
    * @param configJson
    * @return AssignmentResult
    **/
    @AuraEnabled
    public static AssignmentResult assignEncargoWithConfig(Id encargoId, String configJson) {
        AssignmentConfig config = new AssignmentConfig();
        if (!String.isBlank(configJson)) {
            applyConfigOverrides(config, configJson);
        }
        return assignEncargo(encargoId, config, false);
    }

    // Entrada para Flow: recebe uma lista de encargos e devolve resultados.

    /**
    * @description Assigns providers to multiple Encargos (Orders) with an option for manual or automatic mode. This method processes a list of requests, each containing an Encargo ID and a mode flag, and returns the assignment results for each request.
    * @author Afonso Duque | 11-02-2026
    * @param requests
    * @return List<AssignmentResult>
    **/
    @InvocableMethod(label='Assign Provider' description='Assigns provider(s) to Encargos with manual/auto mode')
    public static List<AssignmentResult> assignProvidersWithMode(List<FlowRequestWithMode> requests) {
        List<AssignmentResult> results = new List<AssignmentResult>();
        if (requests != null) {
            for (FlowRequestWithMode req : requests) {
                results.add(assignEncargo(req.encargoId, null, req.isManual));
            }
        }
        return results;
    }


    // Avalia todos os fornecedores e devolve snapshots com elegibilidade e pontuação.
    // Aqui é criada a lista completa de avaliações. No fim, é gerado um
    // resumo por fases (quantos restaram depois de cada filtro).

    /**
    * @description Evaluates all providers and returns snapshots with eligibility and scores. This method creates the complete list of evaluations and generates a summary by phases (how many remained after each filter).
    * @author Afonso Duque | 11-02-2026
    * @param encargo
    * @param providers
    * @param config
    * @return List<ProviderSnapshot>
    **/
    @AuraEnabled
    public static List<ProviderSnapshot> evaluate(SObject encargo, List<SObject> providers, AssignmentConfig config) {
        List<ProviderSnapshot> results = new List<ProviderSnapshot>();
        for (SObject provider : providers) {
            ProviderSnapshot snap = evaluateProvider(encargo, provider, config);
            results.add(snap);
        }
        logEvaluationSummary(results, config);
        return results;
    }

    // Seleciona o melhor fornecedor: maior pontuação e elegível.
    // Se nenhum for elegível, devolve null.
    /*@AuraEnabled
    public static ProviderSnapshot selectBest(List<ProviderSnapshot> evaluations) {
        ProviderSnapshot best;
        for (ProviderSnapshot snap : evaluations) {
            if (snap.eligible) {
                if (best == null || snap.score > best.score) {
                    best = snap;
                }
            }
        }
        return best;
    }*/

    /**
    * @description Selects the best provider based on the highest score and eligibility. In case of a tie in scores, a deterministic tie-breaker is applied based on provider IDs to avoid flapping. If no providers are eligible, it returns null.
    * @author Afonso Duque | 11-02-2026
    * @param evaluations
    * @return ProviderSnapshot
    **/
    @AuraEnabled
    public static ProviderSnapshot selectBest(List<ProviderSnapshot> evaluations) {
        ProviderSnapshot best;
        if (evaluations != null && !evaluations.isEmpty()) {
            for (ProviderSnapshot snap : evaluations) {
                if (snap != null && snap.eligible) {
                    if (best != null) {
                        if (snap.score > best.score) {
                            best = snap;
                        } else if (snap.score == best.score) {
                            // Deterministic tie-breaker to avoid flapping.
                            best = compareSnapshotsIds(best, snap);
                        }
                    } else {
                        best = snap;
                    }
                }
            }
        }
        return best;
    }

    /**
    * @description Compares two ProviderSnapshot instances based on their provider IDs to determine a deterministic tie-breaker in case of equal scores. The snapshot with the "lower" provider ID (lexicographically) is considered better. This method assumes that both snapshots are non-null and have valid provider IDs.
    * @author Afonso Duque | 11-02-2026
    * @param best
    * @param snap
    * @return ProviderSnapshot
    **/
    public static ProviderSnapshot compareSnapshotsIds(ProviderSnapshot best, ProviderSnapshot snap) {
        String a = String.valueOf(best.providerId);
        String b = String.valueOf(snap.providerId);
        return (b != null && (a == null || b < a)) ? snap : best;
    }

    /*@AuraEnabled
    public static ProviderSnapshot selectBest(List<ProviderSnapshot> evaluations) {
        ProviderSnapshot best;
        if (evaluations == null || evaluations.isEmpty()) {
            return null;
        }

        for (ProviderSnapshot snap : evaluations) {
            if (snap == null || snap.eligible != true) {
                continue;
            }
            if (best == null) {
                best = snap;
                continue;
            }
            if (snap.score > best.score) {
                best = snap;
            } else if (snap.score == best.score) {
                // Deterministic tie-breaker to avoid flapping.
                String a = String.valueOf(best.providerId);
                String b = String.valueOf(snap.providerId);
                if (b != null && (a == null || b < a)) {
                    best = snap;
                }
            }
        }
        return best;
    }*/

    // Carrega o encargo usando os campos definidos na configuração.
    // A seleção é dinâmica para permitir parametrização por JSON.

    /**
    * @description Loads the Encargo (Order) using the fields defined in the configuration. The selection is dynamic to allow parameterization via JSON. This method constructs a SOQL query based on the specified fields and retrieves the Encargo record for evaluation.
    * @author Afonso Duque | 11-02-2026
    * @param encargoId
    * @param config
    * @return SObject
    **/
    private static SObject loadEncargo(Id encargoId, AssignmentConfig config) {
        String soql = 'SELECT ' + String.join(getEncargoFields(config), ',') +
            ' FROM ' + config.encargoObjectApiName +
            ' WHERE Id = :encargoId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    // Carrega fornecedores com os campos necessários para a avaliação.
    // Se prefilterByPostalCode=true, já filtra por WorkPostalCodes__c
    // com base no código postal do encargo, reduzindo o universo inicial.

    /**
    * @description Loads providers with the necessary fields for evaluation. If prefilterByPostalCode is true, it already filters by WorkPostalCodes__c based on the postal code of the encargo, reducing the initial universe. This method constructs a dynamic SOQL query to retrieve potential providers based on the active filters and postal code prefiltering defined in the configuration.
    * @author Afonso Duque | 11-02-2026
    * @param encargo
    * @param config
    * @return List<SObject>
    **/
    private static List<SObject> loadProviders(SObject encargo, AssignmentConfig config) {
        String whereClause = config.activeFilter;
        if (!String.isBlank(config.activeField)) {
            whereClause += ' AND ' + config.activeField + ' = true';
        }
        if (config.prefilterByPostalCode == true) {
            String postal = getString(encargo, config.encargoPostalCodeField);
            String postalFilter = buildPostalPrefilterClause(config.providerPostalCodesField, postal, config.postalPrefixMinLength);
            if (!String.isBlank(postalFilter)) {
                whereClause += ' AND (' + postalFilter + ')';
            }
        }

        String soql = 'SELECT ' + String.join(getProviderFields(config), ',') +
            ' FROM ' + config.providerObjectApiName +
            ' WHERE ' + whereClause;

        if (config.debugEnabled == true) {
            System.debug(LoggingLevel.INFO, 'ProviderAssignmentEngine provider query: ' + soql);
        }

        return Database.query(soql);
    }

    // Avalia um único fornecedor contra os critérios do encargo.
    // A ordem dos filtros é importante: calendar -> situation -> urgência -> branch -> type/guild -> postal
    // -> preferências/vetos -> cobertura -> equipamento -> capacidade.
    // O primeiro que falhar marca a fase de exclusão.

    /**
    * @description Evaluates a single provider against the criteria of the encargo. The order of the filters is important: calendar -> situation -> urgency -> branch -> type/guild -> postal -> preferences/vetos -> coverage -> equipment -> capacity. The first one that fails marks the exclusion phase. This method checks each criterion in sequence, marking the provider as ineligible at the first failure and providing detailed reasons for exclusion or eligibility.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @return ProviderSnapshot
    **/
    public static ProviderSnapshot evaluateProvider(SObject encargo, SObject provider, AssignmentConfig config) {
        ProviderSnapshot snap = new ProviderSnapshot(provider);

        // Basic eligibility checks.
        if (!matchesCalendarAvailability(provider, config, snap)) {
            return snap;
        }
        if (!matchesSituation(provider, config, snap)) {
            return snap;
        }
        if (!matchesUrgency(encargo, provider, config, snap)) {
            snap.ineligible('Cobertura de urgencia', EvaluationStage.URGENCY);
            debug(config, snap, 'EXCLUDE URGENCY: encargoUrgent=' + String.valueOf(getBoolean(encargo, config.encargoUrgentField)) +
                ', providerUrgent=' + getString(provider, config.providerUrgentField));
            return snap;
        }
        /*
        if (!matchesBranches(encargo, provider, config, snap)) {
            snap.ineligible('Branch mismatch', EvaluationStage.BRANCH);
            debug(config, snap, 'EXCLUDE BRANCH: encargoBranch=' + getString(encargo, config.encargoBranchField) +
                ', providerBranches=' + String.join(new List<String>(getMultiPicklist(provider, config.branchesField)), ';'));
            return snap;
        }
        */
        if (!matchesTypeAndGuild(encargo, provider, config, snap)) {
            snap.ineligible('Incompatibilidad de tipo/gremio', EvaluationStage.TYPE_GUILD);
            String providerGuildValues = getString(provider, config.providerTypeField);
            String excludedTypes;
            if (config != null && config.supplierGuildQuerySucceeded == true) {
                Id pid = (Id) provider.get('Id');
                Set<String> excluded = pid != null ? config.providerSupplierGuildTypes.get(pid) : null;
                excludedTypes = excluded == null ? null : String.join(new List<String>(excluded), ';');
            }
            debug(config, snap, 'EXCLUDE GUILD: encargoGuild=' + getString(encargo, config.encargoTypeField) +
                ', providerGuild=' + providerGuildValues +
                (String.isBlank(excludedTypes) ? '' : (', excludedActiveTypes=' + excludedTypes)));
            return snap;
        }
        if (!matchesPostalCode(encargo, provider, config, snap)) {
            snap.ineligible('Código postal no cubierto', EvaluationStage.POSTAL);
            debug(config, snap, 'EXCLUDE POSTAL: encargoPostal=' + getString(encargo, config.encargoPostalCodeField) +
                ', providerPostalCodes=' + getString(provider, config.providerPostalCodesField));
            return snap;
        }
        if (!matchesPreferences(encargo, provider, config, snap)) {
            snap.ineligible('Reglas de preferencia/veto', EvaluationStage.PREFERENCES);
            debug(config, snap, 'EXCLUDE PREFERENCES/VETO');
            return snap;
        }
        if (!matchesEquipment(encargo, provider, config, snap)) {
            snap.ineligible('Incompatibilidad de equipo/marca', EvaluationStage.EQUIPMENT);
            debug(config, snap, 'EXCLUDE EQUIPMENT/BRAND');
            return snap;
        }

        // Capacity checks (daily and open).
        CapacityState cap = computeCapacity(provider, config);
        if (!cap.canAssign) {
            snap.ineligible(cap.reason, EvaluationStage.CAPACITY);
            debug(config, snap, 'EXCLUDE CAPACITY: dailyAssigned=' + String.valueOf(cap.dailyAssigned) +
                ', dailyCap=' + String.valueOf(cap.dailyCap) +
                ', openAssigned=' + String.valueOf(cap.openAssigned) +
                ', openCap=' + String.valueOf(cap.openCap));
            return snap;
        }

        // Scoring model.
        snap.score = scoreProvider(encargo, provider, config, cap, snap);
        snap.reason = buildEligibleReason(snap, cap, provider, config);
        snap.eligible = true;
        snap.failureStage = String.valueOf(EvaluationStage.ELIGIBLE);
        debug(config, snap, 'ELIGIBLE: score=' + String.valueOf(snap.score));
        return snap;
    }

    // Calcula o estado de capacidade aplicando fatores de sobrecarga.
    // dailyCap/openCap já incluem os fatores (Overload/Overpending).

    /**
    * @description Computes the capacity state by applying overload factors. The dailyCap/openCap already include the Overload/Overpending factors. This method retrieves the relevant capacity fields from the provider record, applies any applicable overload factors based on defined windows, and determines whether the provider can be assigned additional work based on their current load and effective capacity.
    * @author Afonso Duque | 11-02-2026
    * @param  provider
    * @param  config
    * @return CapacityState
    **/
    private static CapacityState computeCapacity(SObject provider, AssignmentConfig config) {
        CapacityState state = new CapacityState();
        system.debug(config);
        Decimal dailyCap = getDecimal(provider, config.dailyCapacityField);
        Decimal openCap = getDecimal(provider, config.maxOpenField);
        Decimal dailyAssigned = getDecimal(provider, config.dailyAssignedField);
        Decimal openAssigned = getDecimal(provider, config.openAssignedField);

        Decimal overloadFactor = getApplicableFactor(provider, config.overloadWindows, config.overloadFactorField, config.defaultOverloadFactor);
        Decimal overPendingFactor = getApplicableFactor(provider, config.overPendingWindows, config.overPendingFactorField, config.defaultOverPendingFactor);

        Decimal effectiveDailyCap = safeCap(dailyCap) * overloadFactor;
        Decimal effectiveOpenCap = safeCap(openCap) * overPendingFactor;

        Decimal priorityAllowance = safeCap(getDecimal(provider, config.capacityPriorityField));
        state.dailyCap = effectiveDailyCap;
        state.openCap = effectiveOpenCap;
        state.dailyAssigned = safeCap(dailyAssigned);
        state.openAssigned = safeCap(openAssigned);
        state.openPriorityAllowance = priorityAllowance;

        Decimal allowedOpenCap = effectiveOpenCap + priorityAllowance;
        state.canAssign = state.dailyAssigned + 1 <= effectiveDailyCap && state.openAssigned + 1 <= allowedOpenCap;
        if (!state.canAssign) {
            state.reason = 'Capacidad alcanzada';
        }
        return state;
    }

    // Calcula a pontuação do fornecedor com ranking, prioridade e folga de capacidade.
    // Implementa o índice de saturação (IS) e transforma em score:
    // score = -IS * capacityWeight + priorityBonus + preferenceBonus + rankingScore

    /**
    * @description Calculates the provider's score based on ranking, priority, and capacity buffer. It implements the saturation index (IS) and transforms it into a score using the formula: score = -IS * capacityWeight + priorityBonus + preferenceBonus + rankingScore. This method considers the provider's current load relative to their effective capacity, any priority status they may have until saturation, specific preference bonuses based on the encargo's criteria, and a general ranking score to compute an overall suitability score for assignment.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  cap
    * @param  snap
    * @return Decimal
    **/
    private static Decimal scoreProvider(SObject encargo, SObject provider, AssignmentConfig config, CapacityState cap, ProviderSnapshot snap) {
        Decimal score = 0;

        Decimal fsa = getApplicableFactor(provider, config.overloadWindows, config.overloadFactorField, config.defaultOverloadFactor);
        Decimal fse = getApplicableFactor(provider, config.overPendingWindows, config.overPendingFactorField, config.defaultOverPendingFactor);

        // IS = (PA/PD * 1/FSA) + (EA/EP * 1/FSE)
        Decimal dailySaturation = cap.dailyCap > 0 ? (cap.dailyAssigned / cap.dailyCap) * (1 / fsa) : 1;
        Decimal allowedOpenCap = cap.openCap + cap.openPriorityAllowance;
        Decimal openCapForScore = allowedOpenCap > 0 ? allowedOpenCap : cap.openCap;
        Decimal openSaturation = openCapForScore > 0 ? (cap.openAssigned / openCapForScore) * (1 / fse) : 1;
        Decimal saturationIndex = dailySaturation + openSaturation;

        Decimal saturationScore = (-1 * saturationIndex) * config.capacityWeight;
        score += saturationScore;

        Boolean priority = getBoolean(provider, config.priorityUntilSaturationField);
        if (priority == true) {
            score += config.priorityBonus;
        }

        // Preference bonuses.
        Decimal preferenceBonus = getPreferenceBonus(encargo, provider, config, snap);
        score += preferenceBonus;

        Decimal ranking = getDecimal(provider, config.rankingField);
        Decimal rankingScore = 0;
        if (config.rankingHigherIsBetter) {
            rankingScore = ranking;
        } else {
            rankingScore = (ranking == null) ? 0 : (100 - ranking);
        }
        score += rankingScore;

        // Mensagem amigável, igual ao "Mais recomendável" do manual
        List<String> detalhes = new List<String>();
        detalhes.add('score ' + formatDecimal(score, 2));
        detalhes.add('servicios diarios ' + formatLoad(cap.dailyAssigned, cap.dailyCap));
        detalhes.add('servicios abiertos ' + formatLoad(cap.openAssigned, allowedOpenCap));
        if (cap.openPriorityAllowance != null && cap.openPriorityAllowance > 0) {
            detalhes.add('prioridad de capacidad +' + formatDecimal(cap.openPriorityAllowance, 0));
        }
        if (priority != null) {
            detalhes.add('prioridad hasta saturación ' + (priority ? 'sí' : 'no'));
        }
        if (ranking != null) {
            detalhes.add('ranking ' + formatDecimal(ranking, 0));
        }
        snap.selectionDetails = 'Más recomendable: ' + String.join(detalhes, ' | ');

        if (config.debugVerbose == true) {
            debug(config, snap, 'Scoring details: saturationIndex=' + String.valueOf(saturationIndex) + ', saturationScore=' + String.valueOf(saturationScore) + ', priority=' + String.valueOf(priority) + ', preferenceBonus=' + String.valueOf(preferenceBonus) + ', ranking=' + String.valueOf(ranking) + ', rankingScore=' + String.valueOf(rankingScore)
            );
        }

        return score.setScale(4);
    }

    /**
    * @description Builds a user-friendly reason string for eligible providers, including score, capacity details, priority status, and ranking. This method compiles various factors that contributed to the provider's eligibility into a readable format that can be displayed in the UI or used for debugging purposes.
    * @author Afonso Duque | 11-02-2026
    * @param  snap
    * @param  cap
    * @param  provider
    * @param  config
    * @return String
    **/
    private static String buildEligibleReason(ProviderSnapshot snap, CapacityState cap, SObject provider, AssignmentConfig config) {
        List<String> parts = new List<String>();
        Decimal allowedOpenCap = cap != null ? cap.openCap + cap.openPriorityAllowance : null;
        parts.add('score ' + formatDecimal(snap != null ? snap.score : null, 2));
        if (cap != null) {
            parts.add('servicios diarios ' + formatLoad(cap.dailyAssigned, cap.dailyCap));
            parts.add('servicios abiertos ' + formatLoad(cap.openAssigned, allowedOpenCap));
            if (cap.openPriorityAllowance != null && cap.openPriorityAllowance > 0) {
                parts.add('prioridad de capacidad +' + formatDecimal(cap.openPriorityAllowance, 0));
            }
        }
        Boolean priority = getBoolean(provider, config.priorityUntilSaturationField);
        if (priority != null) {
            parts.add('prioridad hasta saturación ' + (priority ? 'sí' : 'no'));
        }
        Decimal ranking = getDecimal(provider, config.rankingField);
        if (ranking != null) {
            parts.add('ranking ' + formatDecimal(ranking, 0));
        }
        return parts.isEmpty() ? 'Sin detalles.' : String.join(parts, ' | ');
    }

    /**
     * @description Formats assigned/capacity values as a ratio string (e.g. '3/10').
     * @param assigned Number of assigned jobs.
     * @param capacity Total capacity.
     * @return Formatted ratio string.
     */
    private static String formatLoad(Decimal assigned, Decimal capacity) {
        return formatDecimal(assigned, 0) + '/' + formatDecimal(capacity, 0);
    }

    /**
     * @description Formats a Decimal value to the specified scale, returning '--' for null values.
     * @param value The Decimal value to format.
     * @param scale Number of decimal places.
     * @return Formatted string representation.
     */
    private static String formatDecimal(Decimal value, Integer scale) {
        if (value == null) {
            return '--';
        }
        Integer finalScale = scale == null ? 2 : scale;
        return String.valueOf(value.setScale(finalScale, RoundingMode.HALF_UP));
    }


    // Lista de campos do fornecedor necessários para a avaliação.
    // Só inclui o que é realmente usado para regras e scoring.

    /**
    * @description Builds a list of provider fields required for evaluation, including only those that are actually used for rules and scoring. This method dynamically constructs the list of fields to be included in the SOQL query based on the configuration, ensuring that only relevant data is retrieved for the assignment process.
    * @author Afonso Duque | 11-02-2026
    * @param  config
    * @return List<String>
    **/
    private static List<String> getProviderFields(AssignmentConfig config) {
        Set<String> fields = new Set<String>{ 'Id' };
        fields.add('Name');
        addField(fields, config.branchesField);
        addField(fields, config.providerTypeField);
        addField(fields, config.dailyCapacityField);
        addField(fields, config.maxOpenField);
        addField(fields, config.dailyAssignedField);
        addField(fields, config.openAssignedField);
        addField(fields, config.capacityPriorityField);
        addField(fields, config.priorityUntilSaturationField);
        addField(fields, config.overloadFactorField);
        addField(fields, config.overPendingFactorField);
        addField(fields, config.rankingField);
        addField(fields, config.providerPostalCodesField);
        addField(fields, config.providerUrgentField);
        addField(fields, config.providerOnCallCalendarField);
        addField(fields, config.providerContractedCapitalField);
        addField(fields, config.calendarAvailabilityField);
        addField(fields, config.situationField);
        addField(fields, config.registrationDateField);
        addField(fields, config.terminationDateField);
        return new List<String>(fields);
    }


    // Lista de campos do encargo usados nos filtros e scoring.
    // Só inclui o que é realmente usado nas regras.

    /**
    * @description Builds a list of encargo fields used in filters and scoring, including only those that are actually used in the rules. This method dynamically constructs the list of fields to be included in the SOQL query for loading the encargo based on the configuration, ensuring that only relevant data is retrieved for the evaluation process.
    * @author Afonso Duque | 11-02-2026
    * @param  config
    * @return List<String>
    **/
    private static List<String> getEncargoFields(AssignmentConfig config) {
        Set<String> fields = new Set<String>{ 'Id' };
        addField(fields, config.encargoBranchField);
        addField(fields, config.encargoTypeField);
        addField(fields, config.encargoUrgentField);
        addField(fields, config.encargoCompanyField);
        addField(fields, config.encargoMediatorField);
        addField(fields, config.encargoTradeField);
        addField(fields, config.encargoEquipmentField);
        addField(fields, config.encargoBrandField);
        addField(fields, config.encargoPostalCodeField);
        addField(fields, config.encargoCoverageLimitField);
        addField(fields, config.encargoCaseLookupField);
        return new List<String>(fields);
    }

    // Adiciona campo ao SELECT apenas se não estiver vazio.

    /**
    * @description Adds a field to the SELECT clause only if it is not blank.
    * @author Afonso Duque | 11-02-2026
    * @param  fields
    * @param  fieldName
    **/
    private static void addField(Set<String> fields, String fieldName) {
        if (!String.isBlank(fieldName)) {
            fields.add(fieldName);
        }
    }

    // Cria um resultado de sucesso com fornecedor e score.

    /**
    * @description Builds a success result with the assigned provider and score. This method constructs an AssignmentResult object indicating a successful assignment, including the ID of the assigned provider and the calculated score for that provider.
    * @author Afonso Duque | 11-02-2026
    * @param  providerId
    * @param  score
    * @return AssignmentResult
    **/
    private static AssignmentResult buildSuccessResult(Id providerId, Decimal score) {
        AssignmentResult r = new AssignmentResult();
        r.success = true;
        r.providerId = providerId;
        r.score = score;
        return r;
    }

    // Cria um resultado de erro com mensagem.

    /**
    * @description Builds an error result with a message. This method constructs an AssignmentResult object indicating a failed assignment, including a reason for the failure that can be used for debugging or user feedback.
    * @author Afonso Duque | 11-02-2026
    * @param  message
    * @return AssignmentResult
    **/
    private static AssignmentResult buildErrorResult(String message) {
        AssignmentResult r = new AssignmentResult();
        r.success = false;
        r.reason = message;
        return r;
    }

    // Verifica se o ramo do encargo está nas zonas/ramas do fornecedor.
    // branchesField é multi-valor separado por ';'. Se vazio, passa.
    /*private static Boolean matchesBranches(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        String encargoBranch = getString(encargo, config.encargoBranchField);
        if (String.isBlank(encargoBranch)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Branch check: encargoBranch is blank -> pass');
            }
            return true;
        }
        Set<String> providerBranches = getMultiPicklist(provider, config.branchesField);
        Boolean match = providerBranches.isEmpty() || providerBranches.contains(encargoBranch);
        if (!match || config.debugVerbose == true) {
            debug(config, snap, 'Branch check: encargoBranch=' + encargoBranch + ', providerBranches=' + String.join(new List<String>(providerBranches), ';') + ', match=' + String.valueOf(match));
        }
        return match;
    }*/

    // Verifica se o fornecedor cobre o código postal do encargo.
    // WorkPostalCodes__c pode conter valores exatos ou com wildcard '#'.
    // Ex.: 2882# cobre 28820..28829; 28### cobre 28000..28999.

    /**
    * @description Checks if the provider covers the postal code of the encargo. The WorkPostalCodes__c field can contain exact values or with a '#' wildcard. For example, '2882#' covers '28820' to '28829', and '28###' covers '28000' to '28999'. This method evaluates whether the encargo's postal code matches any of the provider's specified postal codes, taking into account potential wildcards for flexible matching.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesPostalCode(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        if (String.isBlank(config.encargoPostalCodeField)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Postal code check: encargoPostalCodeField is blank -> pass');
            }
            return true;
        }
        String encargoPostal = getString(encargo, config.encargoPostalCodeField);
        if (String.isBlank(encargoPostal)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Postal code check: encargoPostal is blank -> pass');
            }
            return true;
        }
        Set<String> providerPostalCodes = splitValues(getString(provider, config.providerPostalCodesField));
        Boolean match = providerPostalCodes.isEmpty() || matchesPostalCodeWildcard(providerPostalCodes, encargoPostal);
        if (!match || config.debugVerbose == true) {
            debug(config, snap, 'Postal code check: encargoPostal=' + encargoPostal + ', providerPostalCodes=' + String.join(new List<String>(providerPostalCodes), ';') + ', match=' + String.valueOf(match));
        }
        return match;
    }

    // Suporta wildcard com '#' (prefixo). Ex.: 2882# cobre 28820..28829; 28### cobre 28000..28999.

    /**
    * @description Supports wildcard with '#' (prefix). For example, '2882#' covers '28820' to '28829', and '28###' covers '28000' to '28999'. This method checks if the encargo's postal code matches any of the provider's postal codes, considering the possibility of wildcards that allow for prefix matching. If the encargo's postal code starts with the prefix defined by the provider's postal code (up to the '#' character), it is considered a match.
    * @author Afonso Duque | 11-02-2026
    * @param  providerPostalCodes
    * @param  encargoPostal
    * @return Boolean
    **/
    private static Boolean matchesPostalCodeWildcard(Set<String> providerPostalCodes, String encargoPostal) {
        if (String.isBlank(encargoPostal)) {
            return true;
        }
        String encargoNormalized = normalizePostal(encargoPostal);
        for (String code : providerPostalCodes) {
            if (String.isBlank(code)) {
                continue;
            }
            String normalized = normalizePostal(code);
            Integer hashPos = normalized.indexOf('#');
            if (hashPos >= 0) {
                String prefix = normalized.substring(0, hashPos);
                if (encargoNormalized.startsWith(prefix)) {
                    return true;
                }
            } else if (normalized == encargoNormalized) {
                return true;
            }
        }
        return false;
    }

    // Aplica regras de preferência e veto.
    // Se alguma regra VETO fizer match, o fornecedor é excluído.

    /**
    * @description Applies preference and veto rules. If any VETO rule matches, the provider is excluded. This method iterates through the defined preference rules in the configuration, checking if any of them match the current encargo and provider. If a VETO rule matches, it immediately returns false, indicating that the provider is ineligible. If a PREFERENCE rule matches, it can contribute to the provider's score but does not exclude them. If no rules match or only PREFERENCE rules match, the provider passes this check.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesPreferences(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        if (config.preferenceRules.isEmpty()) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Preference/veto check: no rules -> pass');
            }
            return true;
        }
        for (PreferenceRule rule : config.preferenceRules) {
            if (rule.matches(encargo, provider, config)) {
                if (rule.type == PreferenceRuleType.VETO) {
                    debug(config, snap, 'Preference/veto check: VETO matched (providerId=' + String.valueOf(rule.providerId) + ', companyId=' + String.valueOf(rule.companyId) + ', mediatorId=' + String.valueOf(rule.mediatorId) + ', trade=' + String.valueOf(rule.trade) + ')');
                    return false;
                }
                if (config.debugVerbose == true) {
                    debug(config, snap, 'Preference/veto check: PREFERENCE matched (providerId=' + String.valueOf(rule.providerId) + ', companyId=' + String.valueOf(rule.companyId) + ', mediatorId=' + String.valueOf(rule.mediatorId) + ', trade=' + String.valueOf(rule.trade) + ')');
                }
            }
        }
        if (config.debugVerbose == true) {
            debug(config, snap, 'Preference/veto check: no veto matched -> pass');
        }
        return true;
    }

    // Verifica se o Type do fornecedor coincide com o Type do encargo.

    /**
    * @description Checks if the provider's Type matches the encargo's Type. This method evaluates whether the provider's specified type or guild aligns with the requirements of the encargo, taking into account any exclusions defined in the configuration based on supplier guild types.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesTypeAndGuild(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        if (String.isBlank(config.encargoTypeField)) {
            return true;
        }

        // Multi-picklist semantics: if the encargo has multiple values, the provider must contain ALL.
        Set<String> required = getMultiPicklist(encargo, config.encargoTypeField);
        if (required.isEmpty()) {
            return true;
        }

        // Fonte de verdade para matching: sempre o campo do fornecedor (ex.: Account.Guild__c).
        if (String.isBlank(config.providerTypeField)) {
            return false;
        }
        Set<String> providerValues = getMultiPicklist(provider, config.providerTypeField);

        if (providerValues == null || providerValues.isEmpty()) {
            return false;
        }

        for (String req : required) {
            if (!providerValues.contains(req)) {
                return false;
            }
        }

        // SupplierGuild__c (status Active) representa características que devem ser descartadas (férias).
        // Se existir um Type ativo para este fornecedor, exclui quando o encargo o exigir.
        if (config != null && config.supplierGuildQuerySucceeded == true) {
            Id pid = (Id) (provider != null ? provider.get('Id') : null);
            Set<String> excludedActiveTypes = pid != null ? config.providerSupplierGuildTypes.get(pid) : null;
            if (excludedActiveTypes != null && !excludedActiveTypes.isEmpty()) {
                for (String req : required) {
                    if (excludedActiveTypes.contains(req)) {
                        return false;
                    }
                }
            }
        }
        return true;
    }

    // Compatibilidade: carrega tipos excluídos (Status__c='Active') sem filtro por Type.
    /*private static void loadActiveSupplierGuildTypes(List<SObject> providers, AssignmentConfig config) {
        loadActiveSupplierGuildTypes(providers, null, config);
    }*/

    // Carrega os Type do fornecedor a partir de SupplierGuild__c que estejam com Status__c='Active'.
    // Esses Type são considerados excluídos (férias) e devem ser descartados.
    // Se requiredTypes for fornecido, limita a query apenas aos Type que podem excluir o encargo.

    /**
    * @description Loads the provider's types from SupplierGuild__c records that have Status__c='Active'. These types are considered exclusions (e.g., for vacations) and should be discarded. If requiredTypes is provided, it limits the query to only those types that can exclude the encargo. This method attempts to retrieve active supplier guild types based on a configured lookup relationship, and if that fails, it falls back to a common field (Account__c) to maintain compatibility with typical orgs. The results are stored in the configuration for use during provider evaluation.
    * @author Afonso Duque | 11-02-2026
    * @param  providers
    * @param  requiredTypes
    * @param  config
    **/
    private static void loadActiveSupplierGuildTypes(List<SObject> providers, Set<String> requiredTypes, AssignmentConfig config) {
        if (config == null) {
            return;
        }
        config.providerSupplierGuildTypes.clear();
        config.supplierGuildQuerySucceeded = false;

        if (providers == null || providers.isEmpty()) {
            return;
        }
        if (String.isBlank(config.supplierGuildObjectApiName) || String.isBlank(config.supplierGuildProviderLookupField) || String.isBlank(config.supplierGuildTypeField)) {
            return;
        }

        Set<Id> providerIds = new Set<Id>();
        for (SObject p : providers) {
            if (p == null) continue;
            Id pid = (Id) p.get('Id');
            if (pid != null) providerIds.add(pid);
        }
        if (providerIds.isEmpty()) {
            return;
        }

        Set<String> typeFilter = (requiredTypes == null) ? null : new Set<String>(requiredTypes);
        if (typeFilter != null && typeFilter.isEmpty()) {
            // Nada a excluir para este encargo.
            return;
        }

        // First attempt: configured lookup field.
        if (tryLoadSupplierGuildTypesWithLookup(providerIds, config, config.supplierGuildProviderLookupField, typeFilter)) {
            config.supplierGuildQuerySucceeded = true;
            return;
        }

        // Second attempt (common orgs): Account__c.
        config.providerSupplierGuildTypes.clear();
        if (config.supplierGuildProviderLookupField != 'Account__c' && tryLoadSupplierGuildTypesWithLookup(providerIds, config, 'Account__c', typeFilter)) {
            config.supplierGuildQuerySucceeded = true;
            return;
        }

        // Se o objeto/campos não existirem no org, mantém map vazio e segue com fallback (Account.Guild__c).
        if (config.debugEnabled == true) {
            System.debug(LoggingLevel.WARN, 'ProviderAssignmentEngine: failed to query SupplierGuilds. Falling back to provider field.');
        }
    }

    /**
    * @description Attempts to load active supplier guild types using a specified lookup field. This method constructs and executes a dynamic SOQL query based on the provided parameters and updates the configuration with the results. It returns true if the query succeeds without exceptions, otherwise false.
    * @author Afonso Duque | 11-02-2026
    * @param  providerIds
    * @param  config
    * @param  lookupField
    * @param  typeFilter
    * @return Boolean
    **/
    public static Boolean tryLoadSupplierGuildTypesWithLookup(Set<Id> providerIds, AssignmentConfig config, String lookupField, Set<String> typeFilter) {
        try {
            if (String.isBlank(lookupField)) {
                return false;
            }

            String soql = 'SELECT ' + lookupField + ', ' + config.supplierGuildTypeField +
                ' FROM ' + config.supplierGuildObjectApiName +
                ' WHERE ' + lookupField + ' IN :providerIds';

            if (!String.isBlank(config.supplierGuildStatusField) && !String.isBlank(config.supplierGuildActiveStatusValue)) {
                String activeStatus = config.supplierGuildActiveStatusValue;
                soql += ' AND ' + config.supplierGuildStatusField + ' = :activeStatus';
            }

            if (typeFilter != null && !typeFilter.isEmpty()) {
                Set<String> wantedTypes = typeFilter;
                soql += ' AND ' + config.supplierGuildTypeField + ' IN :wantedTypes';
            }

            for (SObject row : Database.query(soql)) {
                Id pid = (Id) row.get(lookupField);
                String typeValue = getString(row, config.supplierGuildTypeField);
                if (pid == null || String.isBlank(typeValue)) {
                    continue;
                }
                if (!config.providerSupplierGuildTypes.containsKey(pid)) {
                    config.providerSupplierGuildTypes.put(pid, new Set<String>());
                }
                config.providerSupplierGuildTypes.get(pid).addAll(splitValues(typeValue));
            }
            return true;
        } catch (Exception e) {
            if (config != null && config.debugEnabled == true) {
                System.debug(LoggingLevel.WARN, 'ProviderAssignmentEngine: SupplierGuild query failed with lookupField=' + lookupField + ' (' + e.getMessage() + ')');
            }
            return false;
        }
    }

    // Calcula o bónus total das preferências.
    // Soma os bonus de todas as regras PREFERENCE que façam match.

    /**
    * @description Calculates the total preference bonus by summing the bonus of all PREFERENCE rules that match the encargo and provider.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Decimal
    **/
    private static Decimal getPreferenceBonus(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        Decimal bonus = 0;
        for (PreferenceRule rule : config.preferenceRules) {
            if (rule.type == PreferenceRuleType.PREFERENCE && rule.matches(encargo, provider, config)) {
                bonus += rule.bonus;
            }
        }
        if (config.debugVerbose == true) {
            debug(config, snap, 'Preference bonus total=' + String.valueOf(bonus));
        }
        return bonus;
    }

    // Verifica cobertura de urgência (piquete / on-call).
    // Se urgente, tenta onCallProviderIds (se estiverem carregados).
    // Caso contrário, usa OnCallCalendar__c (intervalo de meses).
    // Se não existir, usa o campo EmergencyService__c do fornecedor.

    /**
    * @description Checks if the provider meets the urgency requirements of the encargo by evaluating on-call provider lists, on-call calendar intervals, and the emergency service field.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesUrgency(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        Boolean urgent = getBoolean(encargo, config.encargoUrgentField);
        if (!urgent) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Urgency check: encargo not urgent -> pass');
            }
            return true;
        }
        if (!config.onCallProviderIds.isEmpty()) {
            Boolean match = config.onCallProviderIds.contains((Id) provider.get('Id'));
            if (!match || config.debugVerbose == true) {
                debug(config, snap, 'Urgency check: onCallProviderIds size=' + String.valueOf(config.onCallProviderIds.size()) + ', match=' + String.valueOf(match));
            }
            return match;
        }
        if (!String.isBlank(config.providerOnCallCalendarField)) {
            String calendarValue = getString(provider, config.providerOnCallCalendarField);
            if (!String.isBlank(calendarValue)) {
                Boolean match = isWithinOnCallCalendar(calendarValue, System.today());
                if (!match || config.debugVerbose == true) {
                    debug(config, snap, 'Urgency check: onCallCalendar=' + calendarValue + ', match=' + String.valueOf(match));
                }
                return match;
            }
        }
        if (!String.isBlank(config.providerUrgentField)) {
            Boolean match = isTruthy(getString(provider, config.providerUrgentField));
            if (!match || config.debugVerbose == true) {
                debug(config, snap, 'Urgency check: providerUrgentField=' + config.providerUrgentField + ', value=' + getString(provider, config.providerUrgentField) + ', match=' + String.valueOf(match));
            }
            return match;
        }
        if (config.debugVerbose == true) {
            debug(config, snap, 'Urgency check: no provider urgent rule -> pass');
        }
        return true;
    }

    // Verifica se o fornecedor está disponível no dia da semana atual com base no campo CalendarAvailability__c.

    /**
    * @description Checks if the provider is available on the current day of the week based on the CalendarAvailability__c field. This method evaluates the provider's specified availability, which can include specific days of the week or ranges (e.g., "L-V" for Monday to Friday), and determines if the provider is eligible for assignment on the current day. If the field is blank, it assumes availability every day. The method also handles different languages and formats for day codes, ensuring that the availability check is accurate regardless of how the data is entered.
    * @author Afonso Duque | 11-02-2026
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesCalendarAvailability(SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        String availability = getString(provider, config.calendarAvailabilityField);
        if (String.isBlank(availability)) {
            return true; // Se o campo estiver vazio, assume que está disponível todos os dias.
        }

        // Converte para maiúsculas para case-insensitive
        availability = availability.toUpperCase();

        // Padroniza para códigos em espanhol (es)
        String lang = UserInfo.getLanguage();
        String convertedAvailability = availability;
        if (lang.startsWith('en')) {
            convertedAvailability = availability.replace('SUN', 'D').replace('MON', 'L').replace('TUE', 'M').replace('WED', 'X').replace('THU', 'J').replace('FRI', 'V').replace('SAT', 'S');
        } else if (lang.startsWith('pt')) {
            convertedAvailability = availability.replace('DOM', 'D').replace('SEG', 'L').replace('TER', 'M').replace('QUA', 'X').replace('QUI', 'J').replace('SEX', 'V').replace('SAB', 'S');
        }

        // Mapeia os códigos em espanhol: D=Domingo, L=Lunes, M=Martes, X=Miércoles, J=Jueves, V=Viernes, S=Sábado
        Map<String, Integer> dayCodeToNumber = new Map<String, Integer>{
            'D' => 1, 'L' => 2, 'M' => 3, 'X' => 4, 'J' => 5, 'V' => 6, 'S' => 7
        };

        // Get current day of week: 1=Sunday, 2=Monday, ..., 7=Saturday
        Date today = Date.today();
        DateTime dt = DateTime.newInstance(today.year(), today.month(), today.day());
        Integer dayOfWeek = Integer.valueOf(dt.format('u')); // 1=Monday, 7=Sunday
        Integer currentDayOfWeek = (dayOfWeek == 7) ? 1 : dayOfWeek + 1;
        String currentDayCode = null;
        for (String code : dayCodeToNumber.keySet()) {
            if (dayCodeToNumber.get(code) == currentDayOfWeek) {
                currentDayCode = code;
                break;
            }
        }
        debug(config, snap, 'Calendar check: currentDayCode=' + currentDayCode);

        // Parse the availability: if range "A-B", expand to list, else split by space/comma
        List<String> availableDays = new List<String>();
        List<String> parts = convertedAvailability.split('-');
        if (parts.size() == 2) {
            // Range: e.g., "L-V" -> L, M, X, J, V
            String startCode = parts[0].trim();
            String endCode = parts[1].trim();
            Integer startDay = dayCodeToNumber.get(startCode);
            Integer endDay = dayCodeToNumber.get(endCode);
            if (startDay != null && endDay != null) {
                if (startDay <= endDay) {
                    for (Integer d = startDay; d <= endDay; d++) {
                        for (String code : dayCodeToNumber.keySet()) {
                            if (dayCodeToNumber.get(code) == d) {
                                availableDays.add(code);
                                break;
                            }
                        }
                    }
                } else {
                    // Wrap-around: e.g., V-D -> V, S, D
                    for (Integer d = startDay; d <= 7; d++) {
                        for (String code : dayCodeToNumber.keySet()) {
                            if (dayCodeToNumber.get(code) == d) {
                                availableDays.add(code);
                                break;
                            }
                        }
                    }
                    for (Integer d = 1; d <= endDay; d++) {
                        for (String code : dayCodeToNumber.keySet()) {
                            if (dayCodeToNumber.get(code) == d) {
                                availableDays.add(code);
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            // List: e.g., "L M X" or "L,M,X"
            availableDays = convertedAvailability.split('[\\s,]+');
            for (Integer i = 0; i < availableDays.size(); i++) {
                availableDays[i] = availableDays[i].trim().toUpperCase();
            }
        }

        // Check if current day is in available days
        Boolean isAvailable = availableDays.contains(currentDayCode);

        if (!isAvailable) {
            snap.ineligible('No disponible en ' + currentDayCode, EvaluationStage.CALENDAR);
            debug(config, snap, 'EXCLUDE CALENDAR: availability=' + availability + ', currentDay=' + currentDayCode);
            return false;
        }

        return true;
    }

    // Verifica se o fornecedor está de férias baseado no campo Situation__c.
    // Se Situation__c = 'Sí', verifica se hoje está entre RegistrationDate__c e TerminationDate__c.

    /**
    * @description Checks if the provider is on vacation based on the Situation__c field. If Situation__c = 'Sí', it checks if today is between RegistrationDate__c and TerminationDate__c. This method evaluates the provider's situation to determine if they are currently on vacation, which would make them ineligible for assignment. It retrieves the relevant fields from the provider record, compares the dates, and returns false if the provider is determined to be on vacation during the current date.
    * @author Afonso Duque | 11-02-2026
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesSituation(SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        String situation = getString(provider, config.situationField);
        if (String.isBlank(situation) || situation != 'Sí') {
            return true;
        }

        Date regDate = getDate(provider, config.registrationDateField);
        Date termDate = getDate(provider, config.terminationDateField);
        Date today = Date.today();

        if (regDate != null && termDate != null && today >= regDate && today <= termDate) {
            snap.ineligible('De vacaciones', EvaluationStage.SITUATION);
            debug(config, snap, 'EXCLUDE SITUATION: regDate=' + String.valueOf(regDate) + ', termDate=' + String.valueOf(termDate) + ', today=' + String.valueOf(today));
            return false;
        }

        return true;
    }

    // Verifica se o capital contratado do fornecedor cobre o limite do encargo/caso.
    /*private static Boolean matchesCoverageLimit(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        if (config.encargoCoverageLimitValue == null) {
            return true;
        }
        Decimal contracted = getDecimal(provider, config.providerContractedCapitalField);
        if (contracted == null) {
            return true;
        }
        return contracted >= config.encargoCoverageLimitValue;
    }*/

    // Verifica se o fornecedor cobre o equipamento/marca do encargo.
    // Só é aplicado se providerEquipmentBrands estiver preenchido.

    /**
    * @description Checks if the provider covers the equipment/brand of the encargo. This check is only applied if providerEquipmentBrands is populated in the configuration. The method retrieves the equipment and brand information from the encargo, compares it against the allowed equipment/brands for the provider, and determines if there is a match. If the encargo does not specify equipment/brand or if the provider does not have any restrictions, it passes by default. Otherwise, it requires a match to pass.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  provider
    * @param  config
    * @param  snap
    * @return Boolean
    **/
    private static Boolean matchesEquipment(SObject encargo, SObject provider, AssignmentConfig config, ProviderSnapshot snap) {
        if (config.providerEquipmentBrands.isEmpty()) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Equipment/brand check: no equipment map -> pass');
            }
            return true;
        }
        if (String.isBlank(config.encargoEquipmentField) && String.isBlank(config.encargoBrandField)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Equipment/brand check: no encargo equipment/brand fields -> pass');
            }
            return true;
        }
        String equipment = getString(encargo, config.encargoEquipmentField);
        String brand = getString(encargo, config.encargoBrandField);
        if (String.isBlank(equipment) && String.isBlank(brand)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Equipment/brand check: encargo equipment/brand blank -> pass');
            }
            return true;
        }
        Set<String> allowed = config.providerEquipmentBrands.get((Id) provider.get('Id'));
        if (allowed == null || allowed.isEmpty()) {
            debug(config, snap, 'Equipment/brand check: no allowed equipment for provider -> fail');
            return false;
        }
        if (!String.isBlank(equipment) && allowed.contains(equipment)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Equipment/brand check: equipment matched -> pass');
            }
            return true;
        }
        if (!String.isBlank(brand) && allowed.contains(brand)) {
            if (config.debugVerbose == true) {
                debug(config, snap, 'Equipment/brand check: brand matched -> pass');
            }
            return true;
        }
        debug(config, snap, 'Equipment/brand check: no match -> fail');
        return false;
    }

    // Debug helper.

    /**
    * @description Debug helper method that logs messages when debugging is enabled in the configuration. It constructs a log message that includes the provider ID (if available) and the provided message, and outputs it to the debug log. Additionally, if a ProviderSnapshot is provided, it adds the log message to the snapshot's warnings for later reference. This method helps track the evaluation process and understand why certain providers were included or excluded based on the applied rules.
    * @author Afonso Duque | 11-02-2026
    * @param  config
    * @param  snap
    * @param  message
    **/
    private static void debug(AssignmentConfig config, ProviderSnapshot snap, String message) {
        if (config != null && config.debugEnabled) {
            String providerId = snap != null ? String.valueOf(snap.providerId) : '';
            String log = 'ProviderAssignmentEngine ' + (String.isBlank(providerId) ? '' : ('[' + providerId + '] ')) + message;
            System.debug(LoggingLevel.INFO, log);
            if (snap != null) {
                snap.warnings.add(log);
            }
        }
    }

    // Resolve o limite de cobertura do encargo (Order) ou do caso associado.

    /**
    * @description Resolves the coverage limit of the encargo (Order) or the associated case. This method checks the configuration for fields that specify where to find the coverage limit value, either directly on the encargo or through a lookup to a case. It retrieves the relevant values and stores the resolved coverage limit in the configuration for later use during provider evaluation. If the necessary fields are not configured or if the values cannot be retrieved, it leaves the coverage limit as null, which effectively means there is no coverage limit constraint for matching providers.
    * @author Afonso Duque | 11-02-2026
    * @param  encargo
    * @param  config
    **/
    private static void resolveCoverageLimit(SObject encargo, AssignmentConfig config) {
        if (config == null) {
            return;
        }
        config.encargoCoverageLimitValue = null;

        if (!String.isBlank(config.encargoCoverageLimitField)) {
            config.encargoCoverageLimitValue = getDecimal(encargo, config.encargoCoverageLimitField);
            return;
        }

        if (String.isBlank(config.caseCoverageLimitField) || String.isBlank(config.encargoCaseLookupField)) {
            return;
        }

        Id caseId = (Id) encargo.get(config.encargoCaseLookupField);
        if (caseId == null) {
            return;
        }

        String soql = 'SELECT ' + config.caseCoverageLimitField + ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        if (!rows.isEmpty()) {
            config.encargoCoverageLimitValue = getDecimal(rows[0], config.caseCoverageLimitField);
        }
    }

    // Obtém o fator aplicável considerando janelas de calendário.
    // Se houver janelas ativas para o fornecedor, usa o fator do campo;
    // senão, usa o fallback.

    /**
    * @description Gets the applicable factor considering calendar windows. If there are active windows for the provider, it uses the factor from the specified field; otherwise, it uses the fallback value. This method retrieves the raw value of the factor field to handle cases where it might be entered as a percentage string (e.g., "30%") and normalizes it to a decimal multiplier (e.g., 1.3). It then checks if there are any calendar windows defined and if any of them are currently active for the provider. If an active window is found, it returns the normalized factor; if not, it returns the fallback value. This allows for dynamic adjustment of factors based on time-based conditions defined in calendar windows.
    * @author Afonso Duque | 11-02-2026
    * @param  provider
    * @param  windows
    * @param  fieldName
    * @param  fallback
    * @return Decimal
    **/
    private static Decimal getApplicableFactor(SObject provider, List<CalendarWindow> windows, String fieldName, Decimal fallback) {
        // Retrieve the raw string value of the field
        String rawValue = getString(provider, fieldName);
        Decimal factor = getDecimal(provider, fieldName);

        // Normalize the factor value, ensuring percentage strings are handled
        factor = normalizeFactorValue(factor, rawValue);
        if (factor == null) {
            factor = fallback;
        }

        if (windows == null || windows.isEmpty()) {
            return factor;
        }
        for (CalendarWindow window : windows) {
            if (window.isActiveFor((Id) provider.get('Id'), System.now())) {
                return factor;
            }
        }
        return fallback;
    }

    // Normaliza fator quando vem como percentagem (ex.: "30%" -> 1.3).

    /**
    * @description Normalizes the factor value when it comes as a percentage (e.g., "30%" -> 1.3). This method checks if the raw value contains a percentage sign and, if so, converts the numeric value to a multiplier by dividing by 100 and adding 1. If the raw value does not contain a percentage sign, it returns the numeric value as is. This allows for flexible input of factor values, enabling users to specify them either as direct multipliers or as percentage increases.
    * @author Afonso Duque | 11-02-2026
    * @param  numericValue
    * @param  rawValue
    * @return Decimal
    **/
    private static Decimal normalizeFactorValue(Decimal numericValue, String rawValue) {
        if (numericValue == null) {
            return null;
        }
        if (!String.isBlank(rawValue) && rawValue.contains('%')) {
            Decimal pct = numericValue;
            return 1 + (pct / 100);
        }
        return numericValue;
    }

    // Aplica overrides de configuração vindos em JSON.
    // Permite mudar campos/regas sem alterar código.

    /**
    * @description Applies configuration overrides coming in JSON format. This method allows for dynamic changes to the configuration fields and rules without modifying the code. It deserializes the provided JSON string into a map and iterates through the keys, applying the values to the corresponding fields in the configuration object. If any keys in the JSON do not match valid configuration fields, they are ignored, allowing for flexible and extensible configuration management.
    * @author Afonso Duque | 11-02-2026
    * @param  config
    * @param  configJson
    **/
    private static void applyConfigOverrides(AssignmentConfig config, String configJson) {
        Map<String, Object> mapValue = (Map<String, Object>) JSON.deserializeUntyped(configJson);
        if (mapValue != null) {
            for (String key : mapValue.keySet()) {
                try {
                    config.put(key, mapValue.get(key));
                } catch (Exception e) {
                    // Ignore invalid keys.
                }
            }
        }
    }

    // Garante que null vira 0 nas capacidades.

    /**
    * @description Ensures that null values are converted to 0 in capacity fields. This method takes a Decimal value and returns 0 if the value is null, otherwise it returns the original value. This is useful for capacity fields where a null value should be treated as zero capacity, ensuring that calculations and comparisons can be performed without encountering null-related issues.
    * @author Afonso Duque | 11-02-2026
    * @param  value
    * @return Decimal
    **/
    private static Decimal safeCap(Decimal value) {
        return value == null ? 0 : value;
    }

    // Converte campo para Decimal com tolerância a tipos diferentes.

    /**
    * @description Converts a field to Decimal with tolerance for different types. This method attempts to retrieve the value of the specified field from the SObject and convert it to a Decimal, handling various possible input types such as Integer, Long, String (including percentage formats), and Decimal itself. If the conversion is not possible or if the field is blank, it returns null. This allows for flexible handling of numeric fields that may be stored in different formats or types in Salesforce.
    * @author Afonso Duque | 11-02-2026
    * @param  s
    * @param  field
    * @return Decimal
    **/
    public static Decimal getDecimal(SObject s, String field) {
        if (s != null && !String.isBlank(field)) {
            Object v = s.get(field);
            if (v == null) {
                return null;
            }
            if (v instanceof Decimal) {
                return (Decimal) v;
            }
            if (v instanceof Integer) {
                return Decimal.valueOf((Integer) v);
            }
            if (v instanceof Long) {
                return Decimal.valueOf((Long) v);
            }
            if (v instanceof String) {
                try {
                    return Decimal.valueOf((String) v);
                } catch (Exception e) {
                    return null;
                }
            }
        }
        return null;
    }

    // Converte campo para Boolean.

    /**
    * @description Converts a field to Boolean. This method retrieves the value of the specified field from the SObject and attempts to convert it to a Boolean. It handles cases where the value might be stored as a Boolean or as a String (e.g., "true", "yes", "1" for true). If the conversion is not possible or if the field is blank, it returns null. This allows for flexible handling of boolean fields that may be stored in different formats in Salesforce.
    * @author Afonso Duque | 11-02-2026
    * @param  s
    * @param  field
    * @return Boolean
    **/
    private static Boolean getBoolean(SObject s, String field) {
        if (s != null && !String.isBlank(field)) {
            Object v = s.get(field);
            if (v == null) {
                return null;
            }
            if (v instanceof Boolean) {
                return (Boolean) v;
            }
            if (v instanceof String) {
                return ((String) v).toLowerCase() == 'true';
            }
        }
        return null;
    }

    // Converte campo para Date.

    /**
    * @description Converts a field to Date. This method retrieves the value of the specified field from the SObject and attempts to convert it to a Date. It handles cases where the value might already be a Date or where it might be stored as a String in a recognizable date format. If the conversion is not possible or if the field is blank, it returns null. This allows for flexible handling of date fields that may be stored in different formats in Salesforce.
    * @author Afonso Duque | 11-02-2026
    * @param  s
    * @param  field
    * @return Date
    **/
    public static Date getDate(SObject s, String field) {
        if (s != null && !String.isBlank(field)) {
            Object v = s.get(field);
            if (v == null) {
                return null;
            }
            if (v instanceof Date) {
                return (Date) v;
            }
        }
        return null;
    }

    // Converte campo para String.

    /**
    * @description Converts a field to String. This method retrieves the value of the specified field from the SObject and converts it to a String, handling null values gracefully. If the field is blank or if the SObject is null, it returns null. This allows for flexible handling of string fields that may be stored in different formats in Salesforce, ensuring that the returned value is always a String or null.
    * @author Afonso Duque | 11-02-2026
    * @param  s
    * @param  field
    * @return String
    **/
    private static String getString(SObject s, String field) {
        if (s == null || String.isBlank(field)) {
            return null;
        }
        Object v = s.get(field);
        return v == null ? null : String.valueOf(v);
    }

    // Converte multi-picklist (texto separado por ;) para Set.

    /**
    * @description Converts a multi-picklist field (text separated by ';') to a Set of Strings. This method retrieves the value of the specified field from the SObject, splits it by the ';' delimiter, and trims each part to create a Set of individual values. If the field is blank or if the SObject is null, it returns an empty Set. This allows for flexible handling of multi-picklist fields that may be stored as a single string in Salesforce, enabling easier comparison and evaluation of individual values.
    * @author Afonso Duque | 11-02-2026
    * @param  s
    * @param  field
    * @return Set<String>
    **/
    private static Set<String> getMultiPicklist(SObject s, String field) {
        String v = getString(s, field);
        Set<String> values = new Set<String>();
        if (String.isBlank(v)) {
            return values;
        }
        for (String part : v.split(';')) {
            if (!String.isBlank(part)) {
                values.add(part.trim());
            }
        }
        return values;
    }

    // Converte listas em texto (separadas por ; , ou espaços) em Set.

    /**
    * @description Converts text lists (separated by ; , or spaces) into a Set of Strings. This method splits the input string by common delimiters such as semicolons, commas, and whitespace, trims each part, and adds them to a Set. If the input string is blank, it returns an empty Set. This allows for flexible handling of text lists that may be stored in different formats, enabling easier comparison and evaluation of individual values.
    * @author Afonso Duque | 11-02-2026
    * @param  v
    * @return Set<String>
    **/
    private static Set<String> splitValues(String v) {
        Set<String> values = new Set<String>();
        if (String.isBlank(v)) {
            return values;
        }
        for (String part : v.split('[;,\\s]+')) {
            if (!String.isBlank(part)) {
                values.add(part.trim());
            }
        }
        return values;
    }

    // Gera filtro SOQL baseado no código postal e prefixos com '#'.

    /**
    * @description Generates a SOQL filter clause based on the postal code and prefixes with '#'. This method constructs a dynamic SOQL WHERE clause that checks if the provider's postal code field contains the normalized postal code of the encargo or any of its prefixes followed by a '#' character. It normalizes the postal code by removing non-numeric characters and handles cases where the postal code may be blank. The resulting clause allows for flexible matching of providers based on their postal code coverage, including support for hierarchical postal code structures using '#' as a delimiter.
    * @author Afonso Duque | 11-02-2026
    * @param  providerField
    * @param  encargoPostal
    * @param  minPrefixLength
    * @return String
    **/
    private static String buildPostalPrefilterClause(String providerField, String encargoPostal, Integer minPrefixLength) {
        if (String.isBlank(providerField)) {
            return null;
        }
        String normalized = normalizePostal(encargoPostal);
        if (String.isBlank(normalized)) {
            return null;
        }
        if (minPrefixLength == null || minPrefixLength < 1) {
            minPrefixLength = 1;
        }
        List<String> clauses = new List<String>();
        clauses.add(providerField + ' LIKE \'%' + String.escapeSingleQuotes(normalized) + '%\'');
        Integer maxPrefix = Math.max(minPrefixLength, normalized.length() - 1);
        for (Integer i = minPrefixLength; i < normalized.length(); i++) {
            String prefix = normalized.substring(0, i);
            clauses.add(providerField + ' LIKE \'%' + String.escapeSingleQuotes(prefix) + '#%\'');
        }
        return String.join(clauses, ' OR ');
    }

    /**
    * @description Normalizes the postal code by removing non-numeric characters and converting to lowercase. This method takes a postal code string and removes any characters that are not digits or the '#' character, effectively normalizing the postal code for consistent comparison. If the input value is null, it returns an empty string. This normalization allows for flexible matching of postal codes that may be entered in various formats while still enabling hierarchical matching using '#' as a delimiter.
    * @author Afonso Duque | 11-02-2026
    * @param  v
    * @return String
    **/
    private static String normalizePostal(String v) {
        return v == null ? '' : v.replaceAll('[^0-9#]', '').toLowerCase();
    }

    /**
     * @description Converts a String value to Boolean, treating 'true', 'yes', 'y', 'sim', 'si', and '1' as true.
     * @param v The string to evaluate.
     * @return True if the value matches a truthy token, false otherwise.
     */
    public static Boolean isTruthy(String v) {
        Boolean isTruthy = false;
        if (!String.isBlank(v)) {
            String normalized = v.trim().toLowerCase();
            isTruthy = (normalized == 'true' || normalized == 'yes' || normalized == 'y' || normalized == 'sim' || normalized == 'si' || normalized == '1');
        }
        return isTruthy;
    }

    // Verifica se a data atual está dentro de qualquer intervalo do calendário on-call.
    // Aceita múltiplos intervalos separados por ';' ou ','.
    // Ex.: "Enero-Diciembre", "Enero-Junio; Septiembre-Diciembre".

    /**
    * @description Checks if the current date falls within any of the specified on-call calendar intervals. Supports multiple intervals separated by ';' or ','. For example, "Enero-Diciembre" or "Enero-Junio; Septiembre-Diciembre".
    * @author Afonso Duque | 11-02-2026
    * @param  calendarValue
    * @param  referenceDate
    * @return Boolean
    **/
    public static Boolean isWithinOnCallCalendar(String calendarValue, Date referenceDate) {
        if (String.isBlank(calendarValue) || referenceDate == null) {
            return false;
        }
        Integer currentMonth = referenceDate.month();
        for (String token : calendarValue.split('[;,\n]+')) {
            String interval = token != null ? token.trim() : '';
            if (String.isBlank(interval)) {
                continue;
            }
            String normalized = interval.toLowerCase();
            List<String> parts = normalized.split('\\s*-\\s*');
            if (parts.size() != 2) {
                continue;
            }
            Integer startMonth = parseSpanishMonth(parts[0]);
            Integer endMonth = parseSpanishMonth(parts[1]);
            if (startMonth == null || endMonth == null) {
                continue;
            }
            if (startMonth <= endMonth) {
                if (currentMonth >= startMonth && currentMonth <= endMonth) {
                    return true;
                }
            } else if (currentMonth >= startMonth || currentMonth <= endMonth) {
                // Intervalo que atravessa o ano (ex.: Noviembre-Febrero).
                return true;
            }
        }
        return false;
    }

    /**
    * @description Parses a Spanish month name and returns its corresponding month number (1 for January, 2 for February, etc.). This method handles common Spanish month names, including those with accents, and is case-insensitive. If the input value does not match any recognized month name, it returns null. This allows for flexible handling of month names in Spanish when evaluating on-call calendar intervals or other date-related configurations.
    * @author Afonso Duque | 11-02-2026
    * @param  value
    * @return Integer
    **/
    private static Integer parseSpanishMonth(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String v = value.trim().toLowerCase();
        v = v.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u');
        if (v == 'enero') return 1;
        if (v == 'febrero') return 2;
        if (v == 'marzo') return 3;
        if (v == 'abril') return 4;
        if (v == 'mayo') return 5;
        if (v == 'junio') return 6;
        if (v == 'julio') return 7;
        if (v == 'agosto') return 8;
        if (v == 'septiembre' || v == 'setiembre') return 9;
        if (v == 'octubre') return 10;
        if (v == 'noviembre') return 11;
        if (v == 'diciembre') return 12;
        return null;
    }

    // Configuração do motor: campos, objetos e parâmetros de scoring.
    // Tudo aqui pode ser substituído via JSON (assignEncargoWithConfig).
    public class AssignmentConfig {
        public String providerObjectApiName = 'Account';
        public String encargoObjectApiName = 'Order';

        // Ramos atendidos (multi-valor). Ex.: "Lar;Comércio".
        public String branchesField = 'CoveredTrades__c';
        // Capacidades e contadores (usados apenas para cálculo do score).
        public String dailyCapacityField = 'DailyCapacity__c';
        public String maxOpenField = 'MaxOpenJobs__c';
        public String dailyAssignedField = 'DailyAssignedJobs__c';
        public String openAssignedField = 'AssignedOpenJobs__c';
        public String capacityPriorityField = 'CapacityPriority__c';

        // SupplierGuild__c: usado apenas para excluir características (Type) que estejam de férias.
        // O matching de Guild/Type em si é feito sempre via providerTypeField (ex.: Account.Guild__c).
        public String supplierGuildObjectApiName = 'SupplierGuild__c';
        // Lookup para Account/Supplier dentro de SupplierGuild__c (ajustável via JSON).
        public String supplierGuildProviderLookupField = 'Account__c';
        public String supplierGuildTypeField = 'Type__c';
        public String supplierGuildStatusField = 'Status__c';
        public String supplierGuildActiveStatusValue = 'Active';

        // Tipos excluídos (Status__c='Active') por fornecedor.
        public Map<Id, Set<String>> providerSupplierGuildTypes = new Map<Id, Set<String>>();
        public Boolean supplierGuildQuerySucceeded = false;
        // Prioridade até saturação (boolean). Se vazio, ignora.
        public String priorityUntilSaturationField = '';
        // Fatores de sobrecarga/sobrependente (multiplicam as capacidades).
        public String overloadFactorField = 'OverloadFactor__c';
        public String overPendingFactorField = 'OverpendingFactor__c';
        // Ranking do fornecedor (maior é melhor por defeito).
        public String rankingField = 'Ranking__c';

        // Campos do encargo (Order) usados nas regras.
        public String encargoBranchField = 'Coverage__c';
        public String encargoTypeField = 'Guild__c';
        public String encargoUrgentField = 'Urgent__c';
        public String encargoCompanyField = '';
        public String encargoMediatorField = '';
        // Ofício do encargo.
        public String encargoTradeField = 'SubReason__c';
        public String encargoEquipmentField = '';
        public String encargoBrandField = '';
        // Código postal (encargo) e cobertura do fornecedor.
        public String encargoPostalCodeField = 'BillingPostalCode';
        public String providerPostalCodesField = 'WorkPostalCodes__c';

        // Type/Guild do fornecedor.
        // Para o caso do Guild__c (multi-picklist) em Order/Account, manter como 'Guild__c'.
        // Se precisar do comportamento antigo (Account.Type), override via JSON: providerTypeField='Type'.
        public String providerTypeField = 'Guild__c';

        // Limite de cobertura (Order/Case) vs capital contratado do fornecedor.
        public String providerContractedCapitalField = 'RepairAutonomy__c';
        public String encargoCoverageLimitField = '';
        public String encargoCaseLookupField = 'CaseNumber__c';
        public String caseCoverageLimitField = 'CurrentProvisionAmount__c';
        public Decimal encargoCoverageLimitValue;

        // Urgências: usa OnCallCalendar__c se não houver onCallProviderIds.
        // Fallback para EmergencyService__c se OnCallCalendar__c estiver vazio.
        public String providerUrgentField = 'EmergencyService__c';
        public String providerOnCallCalendarField = 'OnCallCalendar__c';
        // Campo de disponibilidade calendária.
        public String calendarAvailabilityField = 'CalendarAvailability__c';
        // Campos de situação/vacation.
        public String situationField = 'Situation__c';
        public String registrationDateField = 'RegistrationDate__c';
        public String terminationDateField = 'TerminationDate__c';
        // Logs detalhados por fase e por fornecedor.
        public Boolean debugEnabled = true;
        // Logs extra (comparações detalhadas). Mantém o log limpo quando false.
        public Boolean debugVerbose = false;
        // Pré-filtro por código postal já na query inicial.
        public Boolean prefilterByPostalCode = true;
        // Tamanho mínimo do prefixo para wildcard (ex.: 28###).
        public Integer postalPrefixMinLength = 2;

        public String activeFilter = 'Id != null';
        public String activeField = 'IsActive__c';

        public Boolean rankingHigherIsBetter = true;
        public Decimal priorityBonus = 10;
        public Decimal capacityWeight = 10;
        public Decimal defaultOverloadFactor = 1;
        public Decimal defaultOverPendingFactor = 1;

        public List<PreferenceRule> preferenceRules = new List<PreferenceRule>();
        public Set<Id> onCallProviderIds = new Set<Id>();
        public Map<Id, Set<String>> providerEquipmentBrands = new Map<Id, Set<String>>();

        public List<CalendarWindow> overloadWindows = new List<CalendarWindow>();
        public List<CalendarWindow> overPendingWindows = new List<CalendarWindow>();

        // Setter dinâmico para overrides via JSON.

        /**
        * @description Dynamic setter for configuration overrides via JSON. This method takes a field name and a value, checks if the field name matches any of the known configuration fields, and if so, sets the corresponding field in the configuration object to the provided value. This allows for flexible updates to the configuration based on JSON input without needing to hardcode each possible override in the code.
        * @author Afonso Duque | 11-02-2026
        * @param  fieldName
        * @param  value
        **/
        public void put(String fieldName, Object value) {
            if (!String.isBlank(fieldName)) {
                if (fieldName == 'providerObjectApiName') this.providerObjectApiName = String.valueOf(value);
                else if (fieldName == 'encargoObjectApiName') this.encargoObjectApiName = String.valueOf(value);
                else if (fieldName == 'branchesField') this.branchesField = String.valueOf(value);
                else if (fieldName == 'dailyCapacityField') this.dailyCapacityField = String.valueOf(value);
                else if (fieldName == 'maxOpenField') this.maxOpenField = String.valueOf(value);
                else if (fieldName == 'dailyAssignedField') this.dailyAssignedField = String.valueOf(value);
                else if (fieldName == 'openAssignedField') this.openAssignedField = String.valueOf(value);
                else if (fieldName == 'capacityPriorityField') this.capacityPriorityField = String.valueOf(value);
                else if (fieldName == 'supplierGuildObjectApiName') this.supplierGuildObjectApiName = String.valueOf(value);
                else if (fieldName == 'supplierGuildProviderLookupField') this.supplierGuildProviderLookupField = String.valueOf(value);
                else if (fieldName == 'supplierGuildTypeField') this.supplierGuildTypeField = String.valueOf(value);
                else if (fieldName == 'supplierGuildStatusField') this.supplierGuildStatusField = String.valueOf(value);
                else if (fieldName == 'supplierGuildActiveStatusValue') this.supplierGuildActiveStatusValue = String.valueOf(value);
                else if (fieldName == 'priorityUntilSaturationField') this.priorityUntilSaturationField = String.valueOf(value);
                else if (fieldName == 'overloadFactorField') this.overloadFactorField = String.valueOf(value);
                else if (fieldName == 'overPendingFactorField') this.overPendingFactorField = String.valueOf(value);
                else if (fieldName == 'rankingField') this.rankingField = String.valueOf(value);
                else if (fieldName == 'encargoBranchField') this.encargoBranchField = String.valueOf(value);
                else if (fieldName == 'encargoTypeField') this.encargoTypeField = String.valueOf(value);
                else if (fieldName == 'encargoUrgentField') this.encargoUrgentField = String.valueOf(value);
                else if (fieldName == 'encargoCompanyField') this.encargoCompanyField = String.valueOf(value);
                else if (fieldName == 'encargoMediatorField') this.encargoMediatorField = String.valueOf(value);
                else if (fieldName == 'encargoTradeField') this.encargoTradeField = String.valueOf(value);
                else if (fieldName == 'encargoEquipmentField') this.encargoEquipmentField = String.valueOf(value);
                else if (fieldName == 'encargoBrandField') this.encargoBrandField = String.valueOf(value);
                else if (fieldName == 'providerContractedCapitalField') this.providerContractedCapitalField = String.valueOf(value);
                else if (fieldName == 'encargoCoverageLimitField') this.encargoCoverageLimitField = String.valueOf(value);
                else if (fieldName == 'encargoCaseLookupField') this.encargoCaseLookupField = String.valueOf(value);
                else if (fieldName == 'caseCoverageLimitField') this.caseCoverageLimitField = String.valueOf(value);
                else if (fieldName == 'providerPostalCodesField') this.providerPostalCodesField = String.valueOf(value);
                else if (fieldName == 'providerTypeField') this.providerTypeField = String.valueOf(value);
                else if (fieldName == 'providerUrgentField') this.providerUrgentField = String.valueOf(value);
                else if (fieldName == 'providerOnCallCalendarField') this.providerOnCallCalendarField = String.valueOf(value);
                else if (fieldName == 'calendarAvailabilityField') this.calendarAvailabilityField = String.valueOf(value);
                else if (fieldName == 'situationField') this.situationField = String.valueOf(value);
                else if (fieldName == 'registrationDateField') this.registrationDateField = String.valueOf(value);
                else if (fieldName == 'terminationDateField') this.terminationDateField = String.valueOf(value);
                else if (fieldName == 'debugVerbose') this.debugVerbose = (Boolean) value;
                else if (fieldName == 'prefilterByPostalCode') this.prefilterByPostalCode = (Boolean) value;
                else if (fieldName == 'postalPrefixMinLength') this.postalPrefixMinLength = (Integer) value;
                else if (fieldName == 'activeFilter') this.activeFilter = String.valueOf(value);
                else if (fieldName == 'activeField') this.activeField = String.valueOf(value);
                else if (fieldName == 'rankingHigherIsBetter') this.rankingHigherIsBetter = (Boolean) value;
                else if (fieldName == 'priorityBonus') this.priorityBonus = (Decimal) value;
                else if (fieldName == 'capacityWeight') this.capacityWeight = (Decimal) value;
                else if (fieldName == 'defaultOverloadFactor') this.defaultOverloadFactor = (Decimal) value;
                else if (fieldName == 'defaultOverPendingFactor') this.defaultOverPendingFactor = (Decimal) value;
            }
        }
    }

    // Snapshot da avaliação de um fornecedor.
    public class ProviderSnapshot {
        public SObject provider;
        @InvocableVariable
        @AuraEnabled
        public Id providerId;
        @InvocableVariable
        @AuraEnabled
        public String providerName;
        @InvocableVariable
        @AuraEnabled
        public Decimal score = 0;
        @InvocableVariable
        @AuraEnabled
        public Boolean eligible = false;
        @InvocableVariable
        @AuraEnabled
        public String reason;
        @InvocableVariable
        @AuraEnabled
        public String selectionDetails;
        @InvocableVariable
        @AuraEnabled
        public List<String> warnings = new List<String>();

        @InvocableVariable
        @AuraEnabled
        public String failureStage;

        public ProviderSnapshot(SObject provider) {
            this.provider = provider;
            this.providerId = (Id) provider.get('Id');
            this.providerName = provider.get('Name') != null ? String.valueOf(provider.get('Name')) : null;
        }

        public void ineligible(String reason, EvaluationStage stage) {
            this.eligible = false;
            this.reason = reason;
            this.failureStage = stage != null ? stage.name() : null;
        }
    }

    private enum EvaluationStage { BRANCH, TYPE_GUILD, POSTAL, PREFERENCES, URGENCY, EQUIPMENT, CAPACITY, CALENDAR, SITUATION, ELIGIBLE }

    /**
    * @description Logs a summary of the provider evaluation results, including counts of total providers, failures at each evaluation stage, and eligible providers. This method is designed to provide insights into the filtering process by categorizing providers based on the stage at which they were filtered out. It also logs the IDs of providers that passed each stage for further analysis. The logging is conditional based on the debugEnabled flag in the configuration to avoid cluttering logs when not needed.
    * @author Afonso Duque | 11-02-2026
    * @param  results
    * @param  config
    **/
    private static void logEvaluationSummary(List<ProviderSnapshot> results, AssignmentConfig config) {
        if (config != null && config.debugEnabled) {

            Integer total = results == null ? 0 : results.size();
            Integer failBranch = 0;
            Integer failTypeGuild = 0;
            Integer failPostal = 0;
            Integer failPreferences = 0;
            Integer failUrgency = 0;
            Integer failEquipment = 0;
            Integer failCapacity = 0;
            Integer eligible = 0;

            Set<Id> afterBranch = new Set<Id>();
            Set<Id> afterTypeGuild = new Set<Id>();
            Set<Id> afterPostal = new Set<Id>();
            Set<Id> afterPreferences = new Set<Id>();
            Set<Id> afterUrgency = new Set<Id>();
            Set<Id> afterEquipment = new Set<Id>();
            Set<Id> afterCapacity = new Set<Id>();
            Set<Id> eligibleIds = new Set<Id>();

            for (ProviderSnapshot snap : results) {
                String stage = snap != null ? snap.failureStage : null;
                Id pid = snap != null ? snap.providerId : null;

                if (stage == EvaluationStage.BRANCH.name()) {
                    failBranch++;
                    continue;
                }
                if (pid != null) afterBranch.add(pid);

                if (stage == EvaluationStage.TYPE_GUILD.name()) {
                    failTypeGuild++;
                    continue;
                }
                if (pid != null) afterTypeGuild.add(pid);

                if (stage == EvaluationStage.POSTAL.name()) {
                    failPostal++;
                    continue;
                }
                if (pid != null) afterPostal.add(pid);

                if (stage == EvaluationStage.PREFERENCES.name()) {
                    failPreferences++;
                    continue;
                }
                if (pid != null) afterPreferences.add(pid);

                if (stage == EvaluationStage.URGENCY.name()) {
                    failUrgency++;
                    continue;
                }
                if (pid != null) afterUrgency.add(pid);

                if (stage == EvaluationStage.EQUIPMENT.name()) {
                    failEquipment++;
                    continue;
                }
                if (pid != null) afterEquipment.add(pid);

                if (stage == EvaluationStage.CAPACITY.name()) {
                    failCapacity++;
                    continue;
                }
                if (pid != null) afterCapacity.add(pid);

                if (stage == EvaluationStage.ELIGIBLE.name()) {
                    eligible++;
                    if (pid != null) eligibleIds.add(pid);
                }
            }

            System.debug(LoggingLevel.INFO,
                'ProviderAssignmentEngine summary: total=' + String.valueOf(total) +
                ', afterBranch=' + String.valueOf(afterBranch.size()) +
                ', afterTypeGuild=' + String.valueOf(afterTypeGuild.size()) +
                ', afterPostal=' + String.valueOf(afterPostal.size()) +
                ', afterPreferences=' + String.valueOf(afterPreferences.size()) +
                ', afterUrgency=' + String.valueOf(afterUrgency.size()) +
                ', afterEquipment=' + String.valueOf(afterEquipment.size()) +
                ', afterCapacity=' + String.valueOf(afterCapacity.size()) +
                ', eligible=' + String.valueOf(eligible)
            );

            System.debug(LoggingLevel.INFO, 'After branch IDs: ' + String.join(toStringList(afterBranch), ';'));
            System.debug(LoggingLevel.INFO, 'After type/guild IDs: ' + String.join(toStringList(afterTypeGuild), ';'));
            System.debug(LoggingLevel.INFO, 'After postal IDs: ' + String.join(toStringList(afterPostal), ';'));
            System.debug(LoggingLevel.INFO, 'After preferences IDs: ' + String.join(toStringList(afterPreferences), ';'));
            System.debug(LoggingLevel.INFO, 'After urgency IDs: ' + String.join(toStringList(afterUrgency), ';'));
            System.debug(LoggingLevel.INFO, 'After equipment IDs: ' + String.join(toStringList(afterEquipment), ';'));
            System.debug(LoggingLevel.INFO, 'After capacity IDs: ' + String.join(toStringList(afterCapacity), ';'));
            System.debug(LoggingLevel.INFO, 'Eligible IDs: ' + String.join(toStringList(eligibleIds), ';'));
        }
    }

    // Cria uma descrição detalhada com os fornecedores que restaram em cada fase.
    // Comentários em português conforme pedido.

    /**
    * @description Builds a detailed description of the provider evaluation process, showing which providers remained after each evaluation stage. This method iterates through the list of ProviderSnapshot results and categorizes providers based on the stage at which they were filtered out. It constructs a multi-line string that summarizes the total number of providers evaluated and lists the providers that passed each stage, as well as those that were ultimately deemed eligible. The output is formatted for readability, with clear section headers for each phase of the evaluation.
    * @author Afonso Duque | 11-02-2026
    * @param  results
    * @return String
    **/
    private static String buildStepByStepDescription(List<ProviderSnapshot> results) {
        if (results == null || results.isEmpty()) {
            return 'Sin proveedores para evaluar.';
        }

        List<String> afterUrgency = new List<String>();
        List<String> afterType = new List<String>();
        List<String> afterPostal = new List<String>();
        List<String> afterPreferences = new List<String>();
        List<String> afterEquipment = new List<String>();
        List<String> afterCapacity = new List<String>();
        List<String> eligible = new List<String>();

        for (ProviderSnapshot snap : results) {
            String stage = snap != null ? snap.failureStage : null;
            String label = getProviderLabel(snap);

            if (stage == EvaluationStage.URGENCY.name()) {
                continue;
            }
            afterUrgency.add(label);

            if (stage == EvaluationStage.TYPE_GUILD.name()) {
                continue;
            }
            afterType.add(label);

            if (stage == EvaluationStage.POSTAL.name()) {
                continue;
            }
            afterPostal.add(label);

            if (stage == EvaluationStage.PREFERENCES.name()) {
                continue;
            }
            afterPreferences.add(label);

            if (stage == EvaluationStage.EQUIPMENT.name()) {
                continue;
            }
            afterEquipment.add(label);

            if (stage == EvaluationStage.CAPACITY.name()) {
                continue;
            }
            afterCapacity.add(label);

            if (stage == EvaluationStage.ELIGIBLE.name()) {
                eligible.add(label);
            }
        }

        List<String> lines = new List<String>();
        lines.add('Resumen de selección de proveedor');
        lines.add('Total evaluados: ' + String.valueOf(results.size()));
        lines.add(formatPhase('Después de urgencia', afterUrgency));
        lines.add(formatPhase('Después de tipo/gremio', afterType));
        lines.add(formatPhase('Después de código postal', afterPostal));
        lines.add(formatPhase('Después de preferencias/vetos', afterPreferences));
        lines.add(formatPhase('Después de equipo/marca', afterEquipment));
        lines.add(formatPhase('Después de capacidad', afterCapacity));
        lines.add(formatPhase('Elegibles', eligible));

        return String.join(lines, '\n');
    }

    // Formata uma fase com cada fornecedor em linha separada.

    /**
    * @description Formats a phase of the provider evaluation with each provider listed on a separate line. This method takes a title for the phase and a list of provider labels, and constructs a string that includes the title followed by a list of providers, each prefixed with a dash. If the list of providers is empty or null, it indicates that no providers passed that phase. This formatting helps to clearly communicate which providers were filtered out at each stage of the evaluation process.
    * @author Afonso Duque | 11-02-2026
    * @param  title
    * @param  providers
    * @return String
    **/
    private static String formatPhase(String title, List<String> providers) {
        if (providers == null || providers.isEmpty()) {
            return title + ':\n- (ninguno)';
        }
        List<String> lines = new List<String>();
        lines.add(title + ':');
        for (String p : providers) {
            lines.add('- ' + p);
        }
        return String.join(lines, '\n');
    }

    // Mostra Id e Nome quando possível.

    /**
    * @description Returns a formatted label for a provider snapshot, including the provider's ID and name if available. If the snapshot is null or lacks identifying information, it returns a placeholder indicating the provider is unknown.
    * @author Afonso Duque | 11-02-2026
    * @param  snap
    * @return String
    **/
    private static String getProviderLabel(ProviderSnapshot snap) {
        if (snap == null) {
            return '(desconocido)';
        }
        String idVal = snap.providerId != null ? String.valueOf(snap.providerId) : '';
        String nameVal = snap.provider != null && snap.provider.get('Name') != null ? String.valueOf(snap.provider.get('Name')) : '';
        if (!String.isBlank(nameVal)) {
            return idVal + ' (' + nameVal + ')';
        }
        return String.isBlank(idVal) ? '(desconocido)' : idVal;
    }

    /**
     * @description Converts a Set of Ids into a List of String representations.
     * @param ids Set of Ids to convert.
     * @return List of Id strings.
     */
    private static List<String> toStringList(Set<Id> ids) {
        List<String> values = new List<String>();
        if (ids == null) {
            return values;
        }
        for (Id idVal : ids) {
            values.add(String.valueOf(idVal));
        }
        return values;
    }

    public class OrderInfo {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String providerType;
        @AuraEnabled
        public List<String> guild;
        @AuraEnabled
        public Boolean urgent;
        @AuraEnabled
        public String caseId;
        @AuraEnabled
        public String providerId;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String typeAssignment;
        @AuraEnabled
        public String stepDescription;
    }

    public class Provider{
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String reason;
        @AuraEnabled
        public String phones;
        @AuraEnabled
        public String emails;
        @AuraEnabled
        public String address;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public Boolean isSelected;

        public Provider(String id, String name, String reason, String phones, String emails, String address, String description) {
            this.id = id;
            this.name = name;
            this.reason = reason;
            this.phones = phones;
            this.emails = emails;
            this.address = address;
            this.description = description;
            this.isSelected = false;
        }
    }

    // Resultado final devolvido ao chamador.
    public class AssignmentResult {
        @InvocableVariable
        @AuraEnabled
        public Boolean success;
        @InvocableVariable
        @AuraEnabled
        public Id providerId;
        @InvocableVariable
        @AuraEnabled
        public Decimal score;
        @InvocableVariable
        @AuraEnabled
        public String reason;
        @InvocableVariable
        @AuraEnabled
        public String stepbyStepDescription;
        @AuraEnabled
        public List<String> warnings = new List<String>();
        // Para modo manual: lista handoff em formato Flow-friendly
        @AuraEnabled
        @InvocableVariable
        public List<PAEFlowProviderSnapshot> manualResults;
        // Para visualização: todos os avaliados (accounts + reasons)
        @AuraEnabled
        @InvocableVariable
        public List<PAEFlowProviderSnapshot> allEvaluatedProviders;
        // Lista de IDs com motivo detalhado (apenas no modo manual)
        @AuraEnabled
        @InvocableVariable
        public List<PAEFlowManualFeedback> manualFeedback;
        @InvocableVariable
        @AuraEnabled
        public List<Provider> providers;
    }

    /**
    * @description Converts a list of ProviderSnapshot objects into a list of PAEFlowProviderSnapshot objects, which are designed to be Flow-friendly for use in Salesforce Flows. This method iterates through the input list of ProviderSnapshot instances, checks for null values, and constructs corresponding PAEFlowProviderSnapshot objects by copying relevant fields such as providerId, providerName, score, eligibility status, reason, selection details, failure stage, and any warnings. The resulting list of PAEFlowProviderSnapshot objects can then be used in Flow contexts for further processing or display.
    * @author Afonso Duque | 11-02-2026
    * @param  snapshots
    * @return List<PAEFlowProviderSnapshot>
    **/
    private static List<PAEFlowProviderSnapshot> toFlowSnapshots(List<ProviderSnapshot> snapshots) {
        List<PAEFlowProviderSnapshot> flowList = new List<PAEFlowProviderSnapshot>();
        if (snapshots == null || snapshots.isEmpty()) {
            return flowList;
        }
        for (ProviderSnapshot snap : snapshots) {
            if (snap == null) {
                continue;
            }
            flowList.add(buildFlowSnapshot(snap));
        }
        return flowList;
    }

    /**
    * @description Builds a PAEFlowProviderSnapshot object from a given ProviderSnapshot instance. This method maps the fields from the ProviderSnapshot, such as providerId, providerName, score, eligibility status, reason, selection details, failure stage, and warnings, into a new PAEFlowProviderSnapshot object. If the input ProviderSnapshot is null, it returns an empty PAEFlowProviderSnapshot with default values. This conversion is essential for preparing the data to be used in Salesforce Flows while maintaining the relevant information about each provider's evaluation.
    * @author Afonso Duque | 11-02-2026
    * @param  snap
    * @return PAEFlowProviderSnapshot
    **/
    private static PAEFlowProviderSnapshot buildFlowSnapshot(ProviderSnapshot snap) {
        PAEFlowProviderSnapshot flowSnap = new PAEFlowProviderSnapshot();
        if (snap == null) {
            return flowSnap;
        }
        flowSnap.providerId = snap.providerId;
        flowSnap.providerName = snap.providerName;
        flowSnap.score = snap.score;
        flowSnap.eligible = snap.eligible;
        flowSnap.reason = snap.reason;
        flowSnap.selectionDetails = snap.selectionDetails;
        flowSnap.failureStage = snap.failureStage;
        if (snap.warnings != null) {
            flowSnap.warnings.addAll(snap.warnings);
        }
        return flowSnap;
    }

    /**
    * @description Converts a list of ProviderSnapshot objects into a list of PAEFlowManualFeedback objects, which are designed to provide manual feedback in Salesforce Flows. This method iterates through the input list of ProviderSnapshot instances, checks for null values and valid provider IDs, and constructs corresponding PAEFlowManualFeedback objects by extracting the providerId and reason for ineligibility. It specifically excludes any snapshots that failed at the Type/Guild evaluation stage to avoid including those reasons in the manual feedback. The resulting list of PAEFlowManualFeedback objects can then be used in Flow contexts to provide detailed feedback on why certain providers were deemed ineligible during the evaluation process.
    * @author Afonso Duque | 11-02-2026
    * @param  snapshots
    * @return List<PAEFlowManualFeedback>
    **/
    private static List<PAEFlowManualFeedback> buildManualFeedback(List<ProviderSnapshot> snapshots) {
        List<PAEFlowManualFeedback> feedback = new List<PAEFlowManualFeedback>();
        if (snapshots == null || snapshots.isEmpty()) {
            return feedback;
        }
        for (ProviderSnapshot snap : snapshots) {
            if (snap == null || snap.providerId == null) {
                continue;
            }
            // Não incluir Type/Guild mismatch
            if (snap.failureStage == String.valueOf(EvaluationStage.TYPE_GUILD)) {
                continue;
            }
            PAEFlowManualFeedback entry = new PAEFlowManualFeedback();
            entry.providerId = snap.providerId;
            entry.reason = !String.isBlank(snap.reason)
                ? snap.reason
                : (snap.failureStage != null ? 'La evaluación se detuvo en ' + snap.failureStage : 'Sin motivo informado.');
            feedback.add(entry);
        }
        return feedback;
    }

    // Resultado do cálculo de capacidade.
    private class CapacityState {
        public Decimal dailyCap;
        public Decimal openCap;
        public Decimal dailyAssigned;
        public Decimal openAssigned;
        public Boolean canAssign;
        public String reason;
        public Decimal openPriorityAllowance;
    }


    // Regra de preferência ou veto.
    public class PreferenceRule {
        public PreferenceRuleType type;
        public Decimal bonus = 0;
        public Id providerId;
        public Id companyId;
        public Id mediatorId;
        public String trade;

        /**
        * @description Evaluates whether a given provider and encargo match the criteria defined in this preference rule, based on the provider ID, company ID, mediator ID, and trade. The method checks each criterion against the corresponding fields in the provider and encargo SObjects, as well as the configuration provided. If any of the criteria do not match, it returns false; otherwise, it returns true, indicating that the rule applies to this provider and encargo combination.
        * @author Afonso Duque | 11-02-2026
        * @param  encargo
        * @param  provider
        * @param  config
        * @return Boolean
        **/
        public Boolean matches(SObject encargo, SObject provider, AssignmentConfig config) {
            if (providerId != null && providerId != (Id) provider.get('Id')) {
                return false;
            }
            if (!String.isBlank(config.encargoCompanyField) && companyId != null && companyId != (Id) encargo.get(config.encargoCompanyField)) {
                return false;
            }
            if (!String.isBlank(config.encargoMediatorField) && mediatorId != null && mediatorId != (Id) encargo.get(config.encargoMediatorField)) {
                return false;
            }
            if (!String.isBlank(trade)) {
                String encTrade = getString(encargo, config.encargoTradeField);
                if (encTrade != trade) {
                    return false;
                }
            }
            return true;
        }
    }

    public enum PreferenceRuleType { PREFERENCE, VETO }

    // Janela de calendário para sobrecarga.
    public class CalendarWindow {
        public Id providerId;
        public DateTime startAt;
        public DateTime endAt;

        /**
        * @description Determines if the calendar window is currently active for a given provider ID and timestamp. The method checks if the providerId matches (if specified) and if the current time falls within the startAt and endAt range. If nowAt is not provided, it defaults to the current system time. This is used to determine if a provider is currently in a state of overload or pending based on predefined calendar windows.
        * @author Afonso Duque | 11-02-2026
        * @param  id
        * @param  nowAt
        * @return Boolean
        **/
        public Boolean isActiveFor(Id id, DateTime nowAt) {
            if (providerId != null && providerId != id) {
                return false;
            }
            if (nowAt == null) {
                nowAt = System.now();
            }
            return (startAt == null || nowAt >= startAt) && (endAt == null || nowAt <= endAt);
        }
    }

    // Entrada de Flow.
    public class FlowRequest {
        @InvocableVariable(required=true)
        public Id encargoId;
    }
}