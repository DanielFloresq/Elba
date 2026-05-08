/**
 * @description       : REST resource controller for receiving and processing Pelayo encargo (assignment) requests
 * @author            : Daniel Flores
 * @group             : 
 * @last modified on  : 07-05-2026
 * @last modified by  : Daniel Flores
**/

@RestResource(urlMapping='/encargo')
global without sharing class PelayoWebServiceController {

    public static final Integer UPDATE_ASSIGNMENT_PELAYO_BATCH_SIZE = 50;
    private static final String CONFIG_LABEL_PELAYO_TOKEN = 'Pelayo Token';

    @TestVisible
    private static String cachedPelayoTokenEndpoint;

    /**
    * @description REST endpoint to receive Pelayo assignment
    * @author Daniel Flores | 04-03-2026
    */
    @HttpPost
    global static void receiveEncargo() {
        RestResponse res = RestContext.response;
        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/json');

        try {
            Id userId = UserInfo.getUserId();
            User u = [
                SELECT Id, Name, Email, Profile.Name, LastName
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            String accountID = u.Name.contains('SLA') ?  [SELECT ID FROM ACCOUNT WHERE NAME LIKE '%SLA%' LIMIT 1].Id : [SELECT ID FROM ACCOUNT WHERE NAME LIKE '%PELAYO%' LIMIT 1].Id;

            PelayoWebServiceStructure.body payload =
                (PelayoWebServiceStructure.body) JSON.deserialize(
                    RestContext.request.requestBody.toString(),
                    PelayoWebServiceStructure.body.class
                );

            if (payload == null) {
                throw new AuraHandledException('Nenhum payload enviado.');
            }

            Contact cont = new Contact();
            if (payload.poliza != null) {
                cont = mapPolizaToContact(payload.poliza, accountID  );
                upsert cont PolicyNumber__c;
            }

            Boolean isClaimCreation = [SELECT ID FROM Case WHERE InsurerClaimReference__c = :payload.siniestro.referenciaSiniestroAseguradora LIMIT 1].isEmpty() ;
            Case c;
            if (payload.siniestro != null) {
                c = new Case();
                PelayoWebServiceStructure.Siniestro sin = payload.siniestro;

             /*    if (sin.descripcionSiniestro != null) c.Subject = sin.descripcionSiniestro; */
                if (sin.descripcionSiniestro != null) c.Description = sin.descripcionSiniestro;

                c.Status = 'Opening';


                c.GrandAccount__c = u.Name.contains('SLA') ? 'SLA': 'PLYO';
                c.AccountId =u.Name.contains('SLA') ?  [SELECT ID FROM ACCOUNT WHERE NAME LIKE '%SLA%' LIMIT 1].Id : [SELECT ID FROM ACCOUNT WHERE NAME LIKE '%PELAYO%' LIMIT 1].Id;
                if (payload.poliza != null && payload.poliza.canalOrigen != null) c.Channel__c = payload.poliza.canalOrigen;
                c.Language = 'ES';
                if (payload.encargo != null && sin.identificadorTipoSiniestro != null) c.Type = sin.identificadorTipoSiniestro;
                if ((c.Type != 'IN' && isClaimCreation)) c.OwnerId =  [SELECT ID FROM Group WHERE NAME = 'Sinistros Reparables' LIMIT 1].Id;
                if (sin.referenciaSiniestroAseguradora != null) c.InsurerClaimReference__c = sin.referenciaSiniestroAseguradora;
                if (sin.descripcionDeclarante != null) c.ClaimantDescription__c = sin.descripcionDeclarante;
                if (sin.nombreDeclarante != null) c.ClaimantName__c = sin.nombreDeclarante;
                if (sin.parentescoAsegurado != null) c.RelationshiptotheInsured__c = sin.parentescoAsegurado;
                if (sin.cuestionario != null) c.QuestionnaireComments__c = sin.cuestionario;
                if (sin.fechaOcurrencia != null) c.ClaimDate__c = sin.fechaOcurrencia;
                if (sin.fechaDeclaracion != null) c.ParticipationDate__c = sin.fechaDeclaracion;
                if (sin.organoVitalAfectado != null) c.VitalOrganAffected__c = sin.organoVitalAfectado;
                if (sin.quiereSMS != null) c.WantsSMSNotifications__c = sin.quiereSMS;
                if (sin.quiereEmail != null) c.WantsEmailNotifications__c = sin.quiereEmail;
                if (sin.franquicia != null) c.Deductible__c = sin.franquicia;
                if (sin.franquiciaConsumida != null) c.DeductibleUsed__c = sin.franquiciaConsumida;
                if (sin.provisionActual != null) c.CurrentProvisionAmount__c = sin.provisionActual;
                if (sin.servicioAsistencia != null) c.AssistanceService__c = sin.servicioAsistencia;
                if (sin.urgente != null) c.Urgent__c = sin.urgente;
                if (sin.nombreTramitador != null) c.ClaimsHandlerName__c = sin.nombreTramitador;
                if (sin.emailTramitador != null) c.ClaimsHandlerEmail__c = sin.emailTramitador;
                if (sin.cuadranteExponencial != null) {
                    c.ExponentialQuadrant__c = sin.cuadranteExponencial;
                }
                if (sin.identificadorTipoSiniestro != null) {
                    c.ClaimTypeIdentifier__c = sin.identificadorTipoSiniestro;
                }
                if (sin.tipoSituacion != null) {
                    c.SituationType__c = sin.tipoSituacion ;
                }
                if (sin.identificadorCausa != null) c.Reason__c = sin.identificadorCausa;
                if (sin.identificadorSubcausa != null) c.SubReason__c = sin.identificadorSubcausa;

                if (sin.danosOcasionados != null && !sin.danosOcasionados.isEmpty()&& sin.danosOcasionados.size()>1  ) {
                    c.DamagesIncurred__c = String.join(sin.danosOcasionados, ';');
                }else if(sin.danosOcasionados != null && !sin.danosOcasionados.isEmpty()){
                    c.DamagesIncurred__c = sin.danosOcasionados[0];
                }

                if (sin.marcadores != null && !sin.marcadores.isEmpty() && sin.marcadores.size()>1) {
                    c.Marcadores__c = String.join(sin.marcadores, ';');
                }else if(sin.marcadores != null && !sin.marcadores.isEmpty()){
                    c.Marcadores__c = sin.marcadores[0];
                }

                if(cont!=null && cont.id != null)c.ContactId = cont.id;
                if (payload.poliza != null) {
                    if (payload.poliza.nombreVia != null) c.MailingInformation__Street__s = payload.poliza.nombreVia;
                    if (payload.poliza.poblacion != null) c.MailingInformation__City__s = payload.poliza.poblacion;
                    if (payload.poliza.codigoPostal != null) c.MailingInformation__PostalCode__s = payload.poliza.codigoPostal;
                    if (payload.poliza.provincia != null) c.MailingInformation__StateCode__s = payload.poliza.provincia;
                    c.MailingInformation__CountryCode__s = 'ES';
                }

                upsert c InsurerClaimReference__c;
            }

            if (payload != null && payload.siniestro != null && c != null && c.Id != null) {
                if (payload.siniestro.garantiasSiniestro != null && !payload.siniestro.garantiasSiniestro.isEmpty()) {
                    List<InsurableCoverage__c> insurableToInsert = mapInsurableCoveragesSiniestro(payload.siniestro.garantiasSiniestro, c.Id);
                    if (!insurableToInsert.isEmpty()) {
                        upsert insurableToInsert ExternalKey__c;
                    }
                }

                if (payload.siniestro.garantiasPoliza != null && !payload.siniestro.garantiasPoliza.isEmpty()) {
                    List<Coverages__c> coveragesToInsert = mapGarantiasPoliza(payload.siniestro.garantiasPoliza, c.Id, cont != null ? cont.Id : null);
                    if (!coveragesToInsert.isEmpty()) {
                        upsert coveragesToInsert ExternalKey__c;
                    }
                }
            }

            String stakeHolderId ;
            // --- Criar e mapear Stakeholders ---
            if (payload.siniestro != null && payload.siniestro.listaImplicados != null) {
                List<Stakeholders__c> listStakeHoldersToUpsert = new List<Stakeholders__c>();
                for (PelayoWebServiceStructure.StakeHolder inputStake : payload.siniestro.listaImplicados) {
                    Stakeholders__c stakeholder = mapStakeholder(inputStake, c);
                    listStakeHoldersToUpsert.add(stakeholder);
                }
                if (!listStakeHoldersToUpsert.isEmpty()) {
                    upsert listStakeHoldersToUpsert  UniqueIdentifier__c;
                    for (Stakeholders__c stakeHolders : listStakeHoldersToUpsert) {
                        if (stakeHolders.Name.contains(cont.FirstName)) {
                            stakeHolderId = stakeHolders.Id;
                        }
                    }

                }
            }

            // --- Criar e mapear Encargo (Order) ---
            Id orderId;
            List<Id> orderIds = new List<Id>();
            Boolean checkIfIsOrderCreate = false;
            if (payload != null && payload.encargo != null && payload.encargo.referenciaEncargoAseguradora != null) {
                checkIfIsOrderCreate = [SELECT ID FROM Order WHERE ChargeIdentifier__c = :payload.encargo.referenciaEncargoAseguradora LIMIT 1].isEmpty();
            }
            
            
            if (isClaimCreation || (payload.encargo != null && payload.encargo.referenciaEncargoAseguradora != null)) {
                
                Order o = mapEncargo(payload.encargo != null ? payload.encargo : null, c);
                if(o != null && o.ChargeIdentifier__c != null){
                    upsert o ChargeIdentifier__c;
                }else if (o != null){
                    insert o;
                }

                if(o != null){
                    List<Order> ordersToRun = new List<Order>{ o };
                    ProviderAssignmentEngine.AssignmentResult ar = ProviderAssignmentEngine.assignEncargo(o.Id, null, false);
                    // Se o algoritmo não devolver fornecedor e existir mais de 1 guild, dividir em múltiplos encargos
                    if (ar == null || ar.providerId == null) {
                        List<String> guildTokens = new List<String>();
                        if (!String.isBlank(o.Guild__c)) {
                            String normalizedGuilds = o.Guild__c.replace(',', ';');
                            for (String g : normalizedGuilds.split(';')) {
                                if (!String.isBlank(g) && g.trim().toUpperCase() != 'NO APLICA') {
                                    guildTokens.add(g.trim());
                                }
                            }
                        }
                        if (guildTokens.size() > 1) {
                            // Atualiza o encargo original com o primeiro guild
                            o.Guild__c = guildTokens[0];
                            update o;
                            // Cria encargos extra (1 por guild) com ChargeIdentifier__c único
                            List<Order> extraOrders = new List<Order>();
                            String baseChargeIdentifier = o.ChargeIdentifier__c;
                            for (Integer idx = 1; idx < guildTokens.size(); idx++) {
                                Order extra = o.clone(false, true, false, false);
                                extra.Guild__c = guildTokens[idx];
                                if (!String.isBlank(baseChargeIdentifier)) {
                                    extra.ChargeIdentifier__c = baseChargeIdentifier + '-' + String.valueOf(idx + 1);
                                }
                                extraOrders.add(extra);
                            }
                            if (!extraOrders.isEmpty()) {
                                insert extraOrders;
                            }
                            ordersToRun.clear();
                            ordersToRun.add(o);
                            ordersToRun.addAll(extraOrders);
                        }
                    }
                    // Executa o algoritmo individualmente para cada encargo
                    List<Order> ordersToUpdate = new List<Order>();
                    List<AlgorithmOutcomes__c> outcomesToInsert = new List<AlgorithmOutcomes__c>();
                    List<Service__c> servicesToInsert = new List<Service__c>();
                    for (Order ord : ordersToRun) {
                        ProviderAssignmentEngine.AssignmentResult r = ProviderAssignmentEngine.assignEncargo(ord.Id, null, false);
                        if (r != null && r.providerId != null) {
                            ord.AccountId = r.providerId;
                            ord.ProviderChoosed__c = r.providerId;
                            ord.Status = 'FirstContact';
                            ordersToUpdate.add(ord);
                        }

                        AlgorithmOutcomes__c algo = new AlgorithmOutcomes__c();
                        algo.Order__c = ord.Id;
                        algo.Type__c = 'Automatic';
                        algo.StepbyStepDescription__c = r.stepbyStepDescription;
                        outcomesToInsert.add(algo);
                    }

                    if(!ordersToUpdate.isEmpty()){
                        c.Status = 'In Progress';
                        update c;
                    }

                    if (payload.encargo != null && hasAdjusterData(payload.encargo) && checkIfIsOrderCreate ) {
                        servicesToInsert.add(mapServicesFromEncargoExpertAssessment(payload.encargo, o.Id, c.Id));
                    }

                    if (!ordersToRun.isEmpty()) {
                        for (Order order : ordersToRun) {
                            if (checkIfIsOrderCreate) {
                                servicesToInsert.addAll(mapServicesFromEncargo(order, c.Id, stakeHolderId));
                            }
                            

                            orderIds.add(order.Id);
                        }
                    }



                    if (!outcomesToInsert.isEmpty()) {
                        insert outcomesToInsert;
                    }
                    if (!ordersToUpdate.isEmpty()) {
                        update ordersToUpdate;
                    }
                    if (!servicesToInsert.isEmpty()) {
                        insert servicesToInsert;
                    }

                    orderId = o.Id;
                }
            }
            
            

            String caseNumber =[SELECT CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1].CaseNumber;
            String caseId = c != null ? String.valueOf(c.Id) : '';
            String siniestroJson = '{"number": "' + caseNumber + '", "id": "' + caseId + '"}';
            List<String> encargosJsonList = new List<String>();
            if (orderIds != null && !orderIds.isEmpty()) {
                List<Order> orders = [SELECT Id, OrderNumber FROM Order WHERE Id IN :orderIds];
                Map<Id, String> orderNumberMap = new Map<Id, String>();
                for (Order ord : orders) {
                    orderNumberMap.put(ord.Id, ord.OrderNumber);
                }
                for (Id oid : orderIds) {
                    String orderNumber = orderNumberMap.containsKey(oid) ? orderNumberMap.get(oid) : '';
                    encargosJsonList.add('{"number": "' + orderNumber + '", "id": "' + String.valueOf(oid) + '"}');
                }
            }
            String encargosJson = '[' + String.join(encargosJsonList, ',') + ']';

            res.responseBody = Blob.valueOf(
                '{"success": true, "message": "Payload procesado con éxito.",' +
                ' "siniestro": ' + siniestroJson + ',' +
                ' "encargos": ' + encargosJson +
                '}'
            );




        }
        catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"success": false, "error": "' + e.getMessage().replace('"','\\"') + '"}');
        }
    }

    /**
    * @description Maps Stakeholder from payload to SObject
    * @author Daniel Flores | 04-03-2026
    * @param inputStake
    * @param ca
    * @return Stakeholders__c
    */
    private static Stakeholders__c mapStakeholder(PelayoWebServiceStructure.StakeHolder inputStake, Case ca) {
        Stakeholders__c stakeholder = new Stakeholders__c();
        if (String.isNotBlank(inputStake.tipoImplicado)) {
            stakeholder.StakeholderType__c = inputStake.tipoImplicado;
        }


        if (inputStake.comentarios != null) stakeholder.Comments__c = inputStake.comentarios;
        if (inputStake.email != null) stakeholder.Email__c = inputStake.email;
        stakeholder.PrimaryMobileContactStartTime__c   = parseTime(inputStake.horaInicioContactoMovilPrincipal);
        stakeholder.PrimaryMobileContactEndTime__c     = parseTime(inputStake.horaFinContactoMovilPrincipal);
        stakeholder.SecondaryMobileContactStartTime__c = parseTime(inputStake.horaInicioContactoMovilSecundario);
        stakeholder.SecondaryMobileContactEndTime__c   = parseTime(inputStake.horaFinContactoMovilSecundario);
        stakeholder.PhoneContactStartTime__c           = parseTime(inputStake.horaInicioContactoFijo);
        stakeholder.PhoneContactEndTime__c             = parseTime(inputStake.horaFinContactoFijo);
        if (inputStake.movilPrincipal != null) stakeholder.PrimaryMobile__c = inputStake.movilPrincipal;
        if (inputStake.movilSecundario != null) stakeholder.SecondaryMobile__c = inputStake.movilSecundario;
        if (inputStake.telefonoFijo != null) stakeholder.Phone__c = inputStake.telefonoFijo;
        if (inputStake.nombreVia != null) stakeholder.Address__Street__s = inputStake.nombreVia;
        if (inputStake.numero != null) stakeholder.StreetNumber__c = inputStake.numero;
        if (inputStake.tipoVia != null) stakeholder.StreetType__c = inputStake.tipoVia;
        if (inputStake.piso != null) stakeholder.Floor__c = inputStake.piso;
        if (inputStake.letra != null) stakeholder.Letter__c = inputStake.letra;
        if (inputStake.escalera != null) stakeholder.BuildingStar__c = inputStake.escalera;
        if (inputStake.poblacion != null) stakeholder.Address__City__s = inputStake.poblacion;
        if (inputStake.provincia != null) stakeholder.Address__StateCode__s = inputStake.provincia;
        if (inputStake.pais != null) stakeholder.Address__CountryCode__s = normalizeCountryCode(inputStake.pais);
        if (inputStake.codigoPostal != null) stakeholder.Address__PostalCode__s = inputStake.codigoPostal;
        if (inputStake.descripcionCompaniaAseguradora != null) stakeholder.InsuranceCompanyDescription__c = inputStake.descripcionCompaniaAseguradora;
        if (inputStake.identificadorCompaniaAseguradora != null) stakeholder.InsuranceCompanyIdentifier__c = inputStake.identificadorCompaniaAseguradora;
        if (inputStake.identificador != null) stakeholder.StakeholderTaxID__c = inputStake.identificador;
        if (inputStake.identificador != null) stakeholder.UniqueIdentifier__c = inputStake.identificador + '_' + ca.InsurerClaimReference__c;


        if (inputStake.tipoIdentificador != null && !String.isBlank(inputStake.tipoIdentificador)) {
            stakeholder.IdentifierType__c =  inputStake.tipoIdentificador;
        }
        if (inputStake.numeroAsegurado != null) stakeholder.PolicyholderNumber__c = inputStake.numeroAsegurado;
        if (inputStake.referenciaSiniestroCompaniaContraria != null) stakeholder.OpposingInsuranceClaimReference__c = inputStake.referenciaSiniestroCompaniaContraria;
        stakeholder.Name = ((inputStake.nombre != null && String.isNotBlank(inputStake.nombre) ? inputStake.nombre + ' '  : '')  +
                            (inputStake.apellido1 != null && String.isNotBlank(inputStake.apellido1) ? inputStake.apellido1+ ' ' : '') +
                            (inputStake.apellido2 != null && String.isNotBlank(inputStake.apellido2) ? inputStake.apellido2 : '')).trim();
        stakeholder.Case__c = ca.Id;
        return stakeholder;
    }

    /**
    * @description Maps assignment from payload to Order
    * @author Daniel Flores | 04-03-2026
    * @param enc
    * @param c
    * @return Order
    */
    private static Order mapEncargo(
    PelayoWebServiceStructure.Encargo enc,
    Case c
    ) {
        Order o = new Order();

        // Relações base
        if (c.AccountId != null) o.AccountId = c.AccountId;
        if (c.ContactId != null) o.BillToContactId = c.ContactId;
        o.OwnerId = UserInfo.getUserId();


        o.Status = 'Order Assignment';

        // Datas
        o.EffectiveDate = enc != null && enc.fechaAsignacion != null
            ? enc.fechaAsignacion
            : Date.today();

        if (enc != null && enc.fechaAsignacion != null){
            o.ChargeIdentifierAssignmentDate__c = enc.fechaAsignacion;
        }else{
            o.ChargeIdentifierAssignmentDate__c = Date.today();
        }


        if (enc != null && enc.horaAsignacion != null){
            o.ChargeIdentifierAssignmentTime__c = enc.horaAsignacion;
        }else{
            o.ChargeIdentifierAssignmentTime__c = DateTime.now().time();
        }


        // Identificadores
        if (enc != null && enc.referenciaEncargoAseguradora != null)
            o.ChargeIdentifier__c = enc.referenciaEncargoAseguradora;

        if (enc != null && enc.referenciaProveedor != null)
            o.ProviderReference__c = enc.referenciaProveedor;

        // Serviço
        if (enc != null && enc.tipoProvider != null)
            o.ProviderType__c =  enc.tipoProvider ;


        if (enc != null && enc.tipoServicio != null)
            o.Type = enc.tipoServicio ;

        if ( enc != null && enc.gremio != null && String.isNotBlank(enc.gremio)) {
            o.Guild__c = enc.gremio;
        }else{

            Set<String> guilds = new Set<String>();
            List<String> danos = new List<String>();
            if (c != null && !String.isBlank(c.DamagesIncurred__c)) {

                danos.addAll(c.DamagesIncurred__c.split(';'));
            }
            if (!danos.isEmpty()) {
                GuildCalculatorService.GuildRequest req = new GuildCalculatorService.GuildRequest();
                req.damage = danos;
                req.grandAccount = c.GrandAccount__c;
                req.reason = c.Reason__c;
                req.subreason = c.Subreason__c;
                List<GuildCalculatorService.GuildRequest> reqs = new List<GuildCalculatorService.GuildRequest>{ req };
                List<GuildCalculatorService.GuildResponse> resp = GuildCalculatorService.getGuild(reqs);
                Integer noAplicaCount = 0;
                for (GuildCalculatorService.GuildResponse r : resp) {
                    if (r != null && !String.isBlank(r.guild)) {
                        for (String g : r.guild.split(';')) {
                            if (!String.isBlank(g)) {
                                if (g.trim().toUpperCase() == 'NO APLICA') {
                                    noAplicaCount++;
                                } else {

                                    String cleanGuild = g.replace(',', ';');
                                    guilds.add(cleanGuild);
                                }
                            }
                        }
                    }
                }
                if (!guilds.isEmpty()) {
                    o.Guild__c = String.join(new List<String>(guilds), ';');
                }else{
                    o.Guild__c = null;
                }

            }
        }

        if(o.ProviderType__c == null && o.Guild__c != null){

            String guildKey = o.Guild__c;
            if (guildKey != null && guildKey.contains(';')) {
                guildKey = guildKey.split(';')[0].trim();
            }
            o.ProviderType__c = [SELECT ProviderType__c FROM DependenceProviderTypeGuild__mdt WHERE Guild__c = :guildKey LIMIT 1].ProviderType__c;
        }


        // Comentários
        if (enc != null && enc.comentario != null) {
            o.Description = enc.comentario;
            o.Comments__c = enc.comentario;
        }

        // Urgência
        if (enc != null && enc.urgente != null){
            o.Urgent__c = enc.urgente;
        }


        if (c.MailingInformation__Street__s != null)
            o.BillingStreet = c.MailingInformation__Street__s;

        if (c.MailingInformation__City__s != null)
            o.BillingCity = c.MailingInformation__City__s;

        if (c.MailingInformation__PostalCode__s != null)
            o.BillingPostalCode = c.MailingInformation__PostalCode__s;

        if (c.MailingInformation__StateCode__s != null)
            o.BillingState = c.MailingInformation__StateCode__s;

        o.BillingCountry = 'ES';

        // Relação com o Case
        o.CaseNumber__c = c.Id;

        return o.Guild__c != null ? o : null;
    }

    /**
    * @description Checks if assignment has expert data
    * @author Daniel Flores | 04-03-2026
    * @param enc
    * @return Boolean
    */
    private static Boolean hasAdjusterData(PelayoWebServiceStructure.Encargo enc) {
        if (enc == null) return false;
        return (enc.nombrePerito != null && String.isNotBlank(enc.nombrePerito)) ||
            (enc.emailPerito != null && String.isNotBlank(enc.emailPerito)) ||
            (enc.telefonoPerito != null && String.isNotBlank(enc.telefonoPerito)) ||
            (enc.movilPerito != null && String.isNotBlank(enc.movilPerito)) ||
            (enc.referenciaperito != null && String.isNotBlank(enc.referenciaperito)) ||
            enc.fechaalta != null ||
            enc.fechacierre != null ||
            (enc.estadoperitacion != null && String.isNotBlank(enc.estadoperitacion)) ||
            (enc.tipoperitacion != null && String.isNotBlank(enc.tipoperitacion)) ||
            (enc.motivoaltaperito != null && String.isNotBlank(enc.motivoaltaperito));
    }

    /**
    * @description Maps expert assessment data to Service__c
    * @author Daniel Flores | 04-03-2026
    * @param enc
    * @param orderId
    * @param caseId
    * @return Service__c
    */
    private static Service__c mapServicesFromEncargoExpertAssessment(
        PelayoWebServiceStructure.Encargo enc,
        Id orderId,
        Id caseId
    ) {
        Service__c service = new Service__c();
        service.Order__c = orderId;
        service.Claim__c = caseId;
        Id expertAssessmentRecordTypeId = getServiceRecordTypeId('ExpertAssessment');
        if (expertAssessmentRecordTypeId != null) {
            service.RecordTypeId = expertAssessmentRecordTypeId;
        }

        if (enc.nombrePerito != null) service.ExpertName__c = enc.nombrePerito;
        if (enc.emailPerito != null) service.ExpertEmail__c = enc.emailPerito;
        if (enc.telefonoPerito != null) service.ExpertPhone__c = enc.telefonoPerito;
        if (enc.movilPerito != null) service.ExpertMobile__c = enc.movilPerito;
        if (enc.referenciaperito != null) service.ExpertReference__c = enc.referenciaperito;
        if (enc.fechaalta != null) service.StartDate__c = enc.fechaalta;
        if (enc.fechacierre != null) service.EndDate__c = enc.fechacierre;
        if (enc.tipoperitacion != null) service.ExpertAssessmentType__c = enc.tipoperitacion;
        if (enc.motivoaltaperito != null) service.ExpertAssignmentReason__c = enc.motivoaltaperito;

        return service;
    }



    /**
    * @description Maps assignment services to Service__c list
    * @author Daniel Flores | 04-03-2026
    * @param o
    * @param caseId
    * @param stakeHolderId
    * @return List<Service__c>
    */
    public static List<Service__c> mapServicesFromEncargo(
        Order o,
        String caseId,
        String stakeHolderId
    ) {
        List<Service__c> services = new List<Service__c>();
        if (o == null) {
            return services;
        }

        // Split by Order.Type (can come as ';' or ',' separated from integrations).
        // Fallback to Guild__c when Type is empty.
        List<String> types = splitTokens(o.Guild__c);
        if (types.isEmpty()) {
            return services;
        }

        Id recordTypeId = getServiceRecordTypeId('Multiguild');

        for (String t : types) {
            if (String.isBlank(t)) continue;

            Service__c service = new Service__c();
            service.Order__c = o.Id;
            service.Claim__c = caseId;
            service.StartDate__c = Date.valueOf(System.today());
            service.Type__c = t;

            if (recordTypeId != null) {
                service.RecordTypeId = recordTypeId;
            }
            if (stakeHolderId != null) {
                service.Stakeholder__c = stakeHolderId;
            }
            service.Status__c = 'Apertura' ;

            services.add(service);
        }

        return services;
    }

    /**
    * @description Normalizes and splits tokens from string (guilds)
    * @author Daniel Flores | 04-03-2026
    * @param raw
    * @return List<String>
    */
    private static List<String> splitTokens(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) {
            return out;
        }
        String normalized = raw.replace(',', ';');
        Set<String> seen = new Set<String>();
        for (String part : normalized.split(';')) {
            if (String.isBlank(part)) continue;
            String token = part.trim();
            if (String.isBlank(token)) continue;
            if (token.toUpperCase() == 'NO APLICA') continue;
            if (seen.contains(token)) continue;
            seen.add(token);
            out.add(token);
        }
        return out;
    }


    /**
    * @description Gets Service__c RecordTypeId by developerName
    * @author Daniel Flores | 04-03-2026
    * @param developerName
    * @return Id
    */
    private static Id getServiceRecordTypeId(String developerName) {
        if (String.isBlank(developerName)) return null;
        Map<String, Schema.RecordTypeInfo> recordTypes =
            Schema.SObjectType.Service__c.getRecordTypeInfosByDeveloperName();
        if (recordTypes != null && recordTypes.containsKey(developerName)) {
            return recordTypes.get(developerName).getRecordTypeId();
        }
        return null;
    }

    /**
    * @description Maps claim coverages to InsurableCoverage__c
    * @author Daniel Flores | 04-03-2026
    * @param garantias
    * @param caseId
    * @return List<InsurableCoverage__c>
    */
    private static List<InsurableCoverage__c> mapInsurableCoveragesSiniestro(
        List<PelayoWebServiceStructure.GarantiaDetalle> garantias,
        Id caseId
    ) {
        List<InsurableCoverage__c> insurableCoverages = new List<InsurableCoverage__c>();
        if (garantias == null) return insurableCoverages;

        for (PelayoWebServiceStructure.GarantiaDetalle garantia : garantias) {
            if (garantia == null) continue;

            InsurableCoverage__c insurable = new InsurableCoverage__c();
            insurable.Claim__c = caseId;

            if (!String.isBlank(garantia.cobertura)) {
                insurable.Coverage__c = garantia.cobertura;
                insurable.ExternalKey__c = garantia.cobertura;
            }
            if (!String.isBlank(garantia.garantia)) {
                insurable.Name = garantia.garantia;
                insurable.ExternalKey__c += insurable.ExternalKey__c != null ? ('_' + garantia.garantia) : garantia.garantia;
            }
            if (caseId != null) {
                insurable.ExternalKey__c += insurable.ExternalKey__c != null ? ('_' + String.valueOf(caseId)) : String.valueOf(caseId);
            }


            Decimal capital = parseDecimal(garantia.capital);
            if (capital != null) insurable.Capital__c = capital;

            Decimal limite = parseDecimal(garantia.limite);
            if (limite != null) insurable.CoverageAmountLimit__c = limite;

            if (garantia.existefranquicia != null) insurable.DeductibleAmountExists__c = garantia.existefranquicia;

            Decimal importeFranquicia = parseDecimal(garantia.importefranquicia);
            if (importeFranquicia != null) insurable.DeductibleAmount__c = importeFranquicia;

            Decimal franquiciaConsumida = parseDecimal(garantia.franquiciaConsumida);
            if (franquiciaConsumida != null) insurable.DeductibleAmountConsumed__c = franquiciaConsumida;

            Decimal limiteUsos = parseDecimal(garantia.limiteusos);
            if (limiteUsos != null) insurable.UsageLimit__c = limiteUsos;

            Decimal usosConsumidos = parseDecimal(garantia.usosconsumidos);
            if (usosConsumidos != null) insurable.UsageConsumed__c = usosConsumidos;

            if (garantia.esprimerriesgo != null) insurable.FirstRisk__c = garantia.esprimerriesgo;

            insurableCoverages.add(insurable);
        }

        return insurableCoverages;
    }

    /**
    * @description Maps policy coverages to Coverages__c
    * @author Daniel Flores | 04-03-2026
    * @param garantias
    * @param caseId
    * @param policyContactId
    * @return List<Coverages__c>
    */
    private static List<Coverages__c> mapGarantiasPoliza(
        List<PelayoWebServiceStructure.GarantiaDetalle> garantias,
        Id caseId,
        Id policyContactId
    ) {
        List<Coverages__c> coverages = new List<Coverages__c>();
        if (garantias == null) return coverages;

        for (PelayoWebServiceStructure.GarantiaDetalle garantia : garantias) {
            if (garantia == null) continue;

            Coverages__c coverage = new Coverages__c();
            coverage.Claim__c = caseId;
            if (policyContactId != null) coverage.Policy__c = policyContactId;

            if (!String.isBlank(garantia.cobertura)) {
                coverage.Coverage__c = garantia.cobertura;
                coverage.ExternalKey__c = garantia.cobertura;
            }
            if (!String.isBlank(garantia.garantia) ) {
                coverage.Name = garantia.garantia;
                coverage.ExternalKey__c += coverage.ExternalKey__c != null ? ('_' + garantia.garantia) : garantia.garantia;
            }

            if (caseId != null) {
                coverage.ExternalKey__c += coverage.ExternalKey__c != null ? ('_' + String.valueOf(caseId)) : String.valueOf(caseId);
            }
            Decimal capital = parseDecimal(garantia.capital);
            if (capital != null) coverage.Capital__c = capital;

            Decimal limite = parseDecimal(garantia.limite);
            if (limite != null) coverage.CoverageAmountLimit__c = limite;

            if (garantia.existefranquicia != null) coverage.DeductibleAmountExists__c = garantia.existefranquicia;

            Decimal importeFranquicia = parseDecimal(garantia.importefranquicia);
            if (importeFranquicia != null) coverage.DeductibleAmount__c = importeFranquicia;

            Decimal franquiciaConsumida = parseDecimal(garantia.franquiciaConsumida);
            if (franquiciaConsumida != null) coverage.DeductibleAmountConsumed__c = franquiciaConsumida;

            Decimal limiteUsos = parseDecimal(garantia.limiteusos);
            if (limiteUsos != null) coverage.UsageLimit__c = limiteUsos;

            Decimal usosConsumidos = parseDecimal(garantia.usosconsumidos);
            if (usosConsumidos != null) coverage.UsageConsumed__c = usosConsumidos;

            if (garantia.esprimerriesgo != null) coverage.FirstRisk__c = garantia.esprimerriesgo;

            coverages.add(coverage);
        }

        return coverages;
    }


    /**
    * @description Converts string to Time
    * @author Daniel Flores | 04-03-2026
    * @param t
    * @return Time
    */
    private static Time parseTime(String t) {
        if (t == null) return null;

        List<String> parts = t.split(':');
        Integer h = 0;
        Integer m = 0;
        Integer s = 0;

        if (parts.size() > 0) h = Integer.valueOf(parts[0]);
        if (parts.size() > 1) m = Integer.valueOf(parts[1]);
        if (parts.size() > 2) s = Integer.valueOf(parts[2]);

        return Time.newInstance(h, m, s, 0);
    }

    /**
    * @description Converts string to Decimal
    * @author Daniel Flores | 04-03-2026
    * @param value
    * @return Decimal
    */
    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) return null;

        String normalized = value.replace(',', '.');
        normalized = normalized.replaceAll('[^0-9\\.-]', '');
        if (String.isBlank(normalized)) return null;

        try {
            return Decimal.valueOf(normalized);
        } catch (Exception e) {
            return null;
        }
    }

    /**
    * @description Normalizes inbound country code values to Salesforce alpha-2 country codes
    * @author Daniel Flores | 18-03-2026
    * @param rawCountryCode
    * @return String
    */
    private static String normalizeCountryCode(String rawCountryCode) {
        if (String.isBlank(rawCountryCode)) {
            return rawCountryCode;
        }

        String trimmed = rawCountryCode.trim();
        if (trimmed.length() == 2 && Pattern.matches('[A-Za-z]{2}', trimmed)) {
            return trimmed.toUpperCase();
        }

        String normalizedNumeric = trimmed;
        if (Pattern.matches('[0-9]+', trimmed)) {
            try {
                normalizedNumeric = String.valueOf(Integer.valueOf(trimmed));
            } catch (Exception e) {
                normalizedNumeric = trimmed;
            }
        }

        Map<String, String> numericToIso2 = getNumericCountryCodeMap();
        return numericToIso2.containsKey(normalizedNumeric)
            ? numericToIso2.get(normalizedNumeric)
            : trimmed.toUpperCase();
    }

    /**
    * @description Returns numeric ISO country code to alpha-2 mapping
    * @author Daniel Flores | 18-03-2026
    * @return Map<String, String>
    */
    private static Map<String, String> getNumericCountryCodeMap() {
        return new Map<String, String>{
            '4' => 'AF', '248' => 'AX', '8' => 'AL', '276' => 'DE', '20' => 'AD', '24' => 'AO', '660' => 'AI',
            '10' => 'AQ', '28' => 'AG', '530' => 'AN', '682' => 'SA', '12' => 'DZ', '32' => 'AR', '51' => 'AM',
            '533' => 'AW', '36' => 'AU', '40' => 'AT', '31' => 'AZ', '44' => 'BS', '48' => 'BH', '50' => 'BD',
            '52' => 'BB', '112' => 'BY', '56' => 'BE', '84' => 'BZ', '204' => 'BJ', '60' => 'BM', '64' => 'BT',
            '68' => 'BO', '70' => 'BA', '72' => 'BW', '74' => 'BV', '76' => 'BR', '96' => 'BN', '100' => 'BG',
            '854' => 'BF', '108' => 'BI', '132' => 'CV', '136' => 'KY', '116' => 'KH', '120' => 'CM', '124' => 'CA',
            '140' => 'CF', '148' => 'TD', '203' => 'CZ', '152' => 'CL', '156' => 'CN', '196' => 'CY', '166' => 'CC',
            '170' => 'CO', '174' => 'KM', '178' => 'CG', '180' => 'CD', '184' => 'CK', '408' => 'KP', '410' => 'KR',
            '384' => 'CI', '188' => 'CR', '191' => 'HR', '192' => 'CU', '208' => 'DK', '212' => 'DM', '214' => 'DO',
            '218' => 'EC', '818' => 'EG', '222' => 'SV', '784' => 'AE', '232' => 'ER', '703' => 'SK', '705' => 'SI',
            '724' => 'ES', '840' => 'US', '581' => 'UM', '233' => 'EE', '231' => 'ET', '234' => 'FO', '608' => 'PH',
            '246' => 'FI', '242' => 'FJ', '250' => 'FR', '266' => 'GA', '270' => 'GM', '268' => 'GE', '239' => 'GS',
            '288' => 'GH', '292' => 'GI', '308' => 'GD', '300' => 'GR', '304' => 'GL', '312' => 'GP', '316' => 'GU',
            '320' => 'GT', '254' => 'GF', '831' => 'GG', '324' => 'GN', '226' => 'GQ', '624' => 'GW', '328' => 'GY',
            '332' => 'HT', '334' => 'HM', '340' => 'HN', '344' => 'HK', '348' => 'HU', '356' => 'IN', '360' => 'ID',
            '364' => 'IR', '368' => 'IQ', '372' => 'IE', '352' => 'IS', '376' => 'IL', '380' => 'IT', '388' => 'JM',
            '392' => 'JP', '832' => 'JE', '400' => 'JO', '398' => 'KZ', '404' => 'KE', '417' => 'KG', '296' => 'KI',
            '414' => 'KW', '418' => 'LA', '426' => 'LS', '428' => 'LV', '422' => 'LB', '430' => 'LR', '434' => 'LY',
            '438' => 'LI', '440' => 'LT', '442' => 'LU', '446' => 'MO', '807' => 'MK', '450' => 'MG', '458' => 'MY',
            '454' => 'MW', '462' => 'MV', '466' => 'ML', '470' => 'MT', '238' => 'FK', '833' => 'IM', '580' => 'MP',
            '504' => 'MA', '584' => 'MH', '474' => 'MQ', '480' => 'MU', '478' => 'MR', '175' => 'YT', '484' => 'MX',
            '583' => 'FM', '498' => 'MD', '492' => 'MC', '496' => 'MN', '499' => 'ME', '500' => 'MS', '508' => 'MZ',
            '104' => 'MM', '516' => 'NA', '520' => 'NR', '162' => 'CX', '524' => 'NP', '558' => 'NI', '562' => 'NE',
            '566' => 'NG', '570' => 'NU', '574' => 'NF', '578' => 'NO', '540' => 'NC', '554' => 'NZ', '512' => 'OM',
            '528' => 'NL', '586' => 'PK', '585' => 'PW', '275' => 'PS', '591' => 'PA', '598' => 'PG', '600' => 'PY',
            '604' => 'PE', '612' => 'PN', '258' => 'PF', '616' => 'PL', '620' => 'PT', '630' => 'PR', '634' => 'QA',
            '826' => 'GB', '638' => 'RE', '646' => 'RW', '642' => 'RO', '643' => 'RU', '732' => 'EH', '90' => 'SB',
            '882' => 'WS', '16' => 'AS', '659' => 'KN', '674' => 'SM', '666' => 'PM', '670' => 'VC', '654' => 'SH',
            '662' => 'LC', '678' => 'ST', '686' => 'SN', '688' => 'RS', '690' => 'SC', '694' => 'SL', '702' => 'SG',
            '760' => 'SY', '706' => 'SO', '144' => 'LK', '748' => 'SZ', '710' => 'ZA', '736' => 'SD', '752' => 'SE',
            '756' => 'CH', '740' => 'SR', '744' => 'SJ', '764' => 'TH', '158' => 'TW', '834' => 'TZ', '762' => 'TJ',
            '86' => 'IO', '260' => 'TF', '626' => 'TL', '768' => 'TG', '772' => 'TK', '776' => 'TO', '780' => 'TT',
            '788' => 'TN', '796' => 'TC', '795' => 'TM', '792' => 'TR', '798' => 'TV', '804' => 'UA', '800' => 'UG',
            '858' => 'UY', '860' => 'UZ', '548' => 'VU', '336' => 'VA', '862' => 'VE', '704' => 'VN', '92' => 'VG',
            '850' => 'VI', '876' => 'WF', '887' => 'YE', '262' => 'DJ', '894' => 'ZM', '716' => 'ZW'
        };
    }

    // ===============================
    // Picklist Mapping (WS -> SF)
    // ===============================
    private static Map<String, Map<String, String>> picklistMappingCache;

    /**
    * @description Maps picklist value from WS to SF
    * @author Daniel Flores | 04-03-2026
    * @param objectName
    * @param fieldName
    * @param wsValue
    * @return String
    */
    private static String mapPicklistValue(String objectName, String fieldName, String wsValue) {
        if (String.isBlank(objectName) || String.isBlank(fieldName) || String.isBlank(wsValue)) {
            return wsValue;
        }
        Map<String, Map<String, String>> cache = getPicklistMappingCache();
        String key = (objectName + '.' + fieldName).toLowerCase();
        if (!cache.containsKey(key)) {
            return wsValue;
        }
        Map<String, String> valueMap = cache.get(key);
        String lookup = wsValue.trim().toLowerCase();
        return valueMap.containsKey(lookup) ? valueMap.get(lookup) : wsValue;
    }

    /**
    * @description Gets picklist mapping cache
    * @author Daniel Flores | 04-03-2026
    * @return Map<String, Map<String, String>>
    */
    private static Map<String, Map<String, String>> getPicklistMappingCache() {
        if (picklistMappingCache != null) {
            return picklistMappingCache;
        }
        picklistMappingCache = new Map<String, Map<String, String>>();

        List<PicklistMapping__mdt> rows = [
            SELECT Object__c, Field__c, SFValue__c, ESValue__c
            FROM PicklistMapping__mdt
        ];

        for (PicklistMapping__mdt row : rows) {
            if (row.Object__c == null || row.Field__c == null || row.ESValue__c == null || row.SFValue__c == null) {
                continue;
            }
            String key = (row.Object__c + '.' + row.Field__c).toLowerCase();
            if (!picklistMappingCache.containsKey(key)) {
                picklistMappingCache.put(key, new Map<String, String>());
            }
            picklistMappingCache.get(key).put(row.ESValue__c.trim().toLowerCase(), row.SFValue__c);
        }

        return picklistMappingCache;
    }

    /**
    * @description Maps policy to Contact
    * @author Daniel Flores | 04-03-2026
    * @param poliza
    * @param accountId
    * @return Contact
    */
    private static Contact mapPolizaToContact(PelayoWebServiceStructure.Poliza poliza, String accountId) {
        Contact c = new Contact();

        // Dados pessoais
        if (poliza.nombre != null) c.FirstName = poliza.nombre;
        if (poliza.apellido1 != null) c.MiddleName = poliza.apellido1;
        if (poliza.apellido2 != null) c.LastName = poliza.apellido2;

        if (poliza.identificador != null) c.IDNumber__c = poliza.identificador;
        if (poliza.tipoIdentificador != null) {
            c.idType__c = poliza.tipoIdentificador;
        }
        if (poliza.email != null) c.Email = poliza.email;
        if (poliza.movil != null) c.MobilePhone = poliza.movil;
        if (poliza.otrosContactos != null) c.OtherContactInfo__c = poliza.otrosContactos;
        if (poliza.idiomaPreferido != null) c.preferredLanguage__c = poliza.idiomaPreferido;

        // Endereço
        if (poliza.nombreVia != null) c.MailingStreet = poliza.nombreVia;
        if (poliza.numero != null) c.buildingNumber__c = poliza.numero;
        if (poliza.tipoVia != null) c.streetType__c = poliza.tipoVia;
        if (poliza.escalera != null) c.stairwell__c = poliza.escalera;
        if (poliza.piso != null) c.floor__c = poliza.piso;
        if (poliza.puerta != null) c.door__c = poliza.puerta;
        if (poliza.codigoPostal != null) c.MailingPostalCode = poliza.codigoPostal;
        if (poliza.poblacion != null) c.MailingCity = poliza.poblacion;
        if (poliza.provincia != null) c.MailingState = poliza.provincia;
        if (poliza.direccionRiesgo != null) c.riskAddress__c = poliza.direccionRiesgo;

        // Informação de seguro
        if (poliza.identificadorPoliza != null) c.PolicyNumber__c = poliza.identificadorPoliza;
        if (poliza.fechaEfecto != null) c.PolicyStartDate__c = poliza.fechaEfecto;
        if (poliza.capitalContinente != null) c.BuildingCapital__c = poliza.capitalContinente;
        if (poliza.capitalContenido != null) c.FillingCapital__c = poliza.capitalContenido;
        if (poliza.capitalRC != null) c.LiabilityCapital__c = poliza.capitalRC;
        /* if (poliza.ramo != null) c.lineOfBusiness__c = poliza.ramo; */

        // Broker / Mediador
        if (poliza.polizaMediada != null) c.isBrokered__c = poliza.polizaMediada;
        if (poliza.clienteVIP != null) c.isVIP__c = poliza.clienteVIP;
        if (poliza.nombreMediador != null) c.brokerName__c = poliza.nombreMediador;
        if (poliza.identificadorMediador != null) c.BrokerCode__c = poliza.identificadorMediador;
        if (poliza.canalOrigen != null) c.sourceChannel__c = poliza.canalOrigen;
        if (accountId != null) c.AccountId = accountId;


        if (poliza.anioConstruccion != null) c.ConstructionYear__c = poliza.anioConstruccion;
        if(poliza.anioUltimaReforma != null) c.LastRenovationYear__c = poliza.anioUltimaReforma;
            
        


        return c;
    }

    /**
    * @description Normalizes a Pelayo endpoint so it always uses the same domain as the token endpoint.
    * @author Daniel Flores | 07-04-2026
    * @param endpoint
    * @return String
    **/
    public static String normalizePelayoEndpoint(String endpoint) {
        return rebuildPelayoEndpointWithTokenDomain(endpoint, getPelayoTokenEndpoint());
    }

    /**
     * @description Rebuilds the given endpoint URL by replacing its origin (scheme + host) with the origin from the token endpoint.
     * @param endpoint Original endpoint URL to normalise
     * @param tokenEndpoint Token endpoint whose origin will be used
     * @return String Normalised endpoint URL, or the original if inputs are blank
     **/
    @TestVisible
    private static String rebuildPelayoEndpointWithTokenDomain(String endpoint, String tokenEndpoint) {
        if (String.isBlank(endpoint) || String.isBlank(tokenEndpoint)) {
            return endpoint;
        }

        String tokenOrigin = extractUrlOrigin(tokenEndpoint);
        String endpointPath = extractUrlPath(endpoint);

        if (String.isBlank(tokenOrigin) || String.isBlank(endpointPath)) {
            return endpoint;
        }

        return tokenOrigin + endpointPath;
    }

    /**
     * @description Extracts the origin (scheme + host) from a URL string (e.g. 'https://api.example.com').
     * @param url Full URL to extract origin from
     * @return String Origin portion of the URL, or null if the URL is blank or malformed
     **/
    @TestVisible
    private static String extractUrlOrigin(String url) {
        if (String.isBlank(url)) {
            return null;
        }

        Integer schemeIndex = url.indexOf('://');
        if (schemeIndex <= 0) {
            return null;
        }

        Integer hostStartIndex = schemeIndex + 3;
        Integer pathStartIndex = url.indexOf('/', hostStartIndex);
        return pathStartIndex > 0 ? url.substring(0, pathStartIndex) : url;
    }

    /**
     * @description Extracts the path portion from a URL string (e.g. '/api/v1/resource').
     * @param url Full URL to extract path from
     * @return String Path portion of the URL, or null if the URL is blank or has no path
     **/
    @TestVisible
    private static String extractUrlPath(String url) {
        if (String.isBlank(url)) {
            return null;
        }

        Integer schemeIndex = url.indexOf('://');
        if (schemeIndex <= 0) {
            return null;
        }

        Integer hostStartIndex = schemeIndex + 3;
        Integer pathStartIndex = url.indexOf('/', hostStartIndex);
        return pathStartIndex > 0 ? url.substring(pathStartIndex) : null;
    }

    /**
     * @description Retrieves and caches the Pelayo token endpoint URL from WebServiceUtils__mdt custom metadata.
     * @return String Token endpoint URL, or null if configuration is missing
     **/
    @TestVisible
    private static String getPelayoTokenEndpoint() {
        if (cachedPelayoTokenEndpoint != null) {
            return cachedPelayoTokenEndpoint;
        }

        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;

        try {
            WebServiceUtils__mdt config = [
                SELECT Endpoint__c
                FROM WebServiceUtils__mdt
                WHERE MasterLabel = :CONFIG_LABEL_PELAYO_TOKEN
                AND isSandbox__c = :isSandbox
                LIMIT 1
            ];
            cachedPelayoTokenEndpoint = config.Endpoint__c;
        } catch (Exception e) {
            cachedPelayoTokenEndpoint = null;
        }

        return cachedPelayoTokenEndpoint;
    }

    /**
    * @description Get Token for Pelayo Services
    * @author Afonso Duque | 23-02-2026
    * @return String
    **/
    public static String getToken() {

        String accessToken;

        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        WebServiceUtils__mdt config = [SELECT Endpoint__c, ClientId__c, ClientSecret__c FROM WebServiceUtils__mdt WHERE MasterLabel = :CONFIG_LABEL_PELAYO_TOKEN AND isSandbox__c =:isSandbox LIMIT 1];

        String basicAuth = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(config.ClientId__c + ':' + config.ClientSecret__c));
        HttpRequest tokenReq = HttpRequestFactory.createHttpRequest(
            'POST',
            config.Endpoint__c,
            new Map<String, String>{
                'Content-Type' => 'application/x-www-form-urlencoded',
                'Authorization' => basicAuth
            },
            'grant_type=client_credentials'
        );

        Http http = new Http();
        HttpResponse tokenRes = http.send(tokenReq);

        System.debug('--- TOKEN RESPONSE ---');
        System.debug('Status Code: ' + tokenRes.getStatusCode());
        System.debug('Body: ' + tokenRes.getBody());

        if (tokenRes.getStatusCode() >= 200 && tokenRes.getStatusCode() < 300) {
            Map<String, Object> tokenJson = (Map<String, Object>) JSON.deserializeUntyped(tokenRes.getBody());
            accessToken = (String) tokenJson.get('token_type') + ' ' + (String) tokenJson.get('access_token');
            System.debug('Access Token (first 40 chars): ' + (accessToken != null ? accessToken.left(40) + '...' : 'NULL'));
        }
        return accessToken;
    }

    /**
    * @description Calls the Pelayo service to create or assign the encargo based on the type parameter. If isFuture is true, it calls the service asynchronously.
    * @author Afonso Duque | 23-02-2026
    * @param orderIds
    * @param type
    * @param isFuture
    **/
    public static void sendEncargoPelayoService(List<String> orderIds, String type, Boolean isFuture){

        if(!orderIds.isEmpty()){
            if(orderIds.size() >= UPDATE_ASSIGNMENT_PELAYO_BATCH_SIZE){
                Database.executeBatch(new UpdateAssignmentPelayoBatch(orderIds, type), UPDATE_ASSIGNMENT_PELAYO_BATCH_SIZE);
            } else if(!isFuture){
                callPutEncargoPelayoServiceFuture(orderIds, type);
            } else {
                System.enqueueJob(new SendEncargoPelayoQueueable(orderIds, type));
            }
        }
    }

    public class SendEncargoPelayoQueueable implements Queueable, Database.AllowsCallouts {
        private final List<String> orderIds;
        private final String type;

        public SendEncargoPelayoQueueable(List<String> orderIds, String type) {
            this.orderIds = orderIds == null ? new List<String>() : new List<String>(orderIds);
            this.type = type;
        }

        /**
         * @description Executes the queued Pelayo assignment callout by delegating to callPutEncargoPelayoService.
         * @param context QueueableContext provided by the platform
         **/
        public void execute(QueueableContext context) {
            if (!orderIds.isEmpty()) {
                callPutEncargoPelayoService(orderIds, type);
            }
        }
    }

    /**
    * @description Calls the Pelayo service to create or assign the encargo based on the type parameter asynchronously.
    * @author Afonso Duque | 23-02-2026
    * @param List<String> orderIds
    * @param String type
    **/
    @Future(callout=true)
    public static void callPutEncargoPelayoServiceFuture(List<String> orderIds, String type){
        callPutEncargoPelayoService(orderIds, type);
    }

    /**
    * @description Calls the Pelayo service to create or assign the encargo based on the type parameter.
    * @author Afonso Duque | 23-02-2026
    * @param List<String> orderIds
    * @param String type
    **/
    public static void callPutEncargoPelayoService(List<String> orderIds, String type){

        String token = getToken();

        if(String.isNotBlank(token)){
            List<Order> listOrders = [
                                            SELECT Id,
                                                CaseNumber__c,
                                                CaseNumber__r.CaseNumber,
                                                CaseNumber__r.InsurerClaimReference__c,
                                                CaseNumber__r.ClaimsHandlerName__c,
                                                AccountId,
                                                Account.Name,
                                                Account.Phone,
                                                Account.SAPEntityCode__c,
                                                Account.RecordType.DeveloperName,
                                                OrderNumber,
                                                ChargeIdentifier__c,
                                                CreatedDate,
                                                EffectiveDate,
                                                Type,
                                                ProviderType__c,
                                                Guild__c,
                                                Status,
                                                Observaciones__c,
                                                Urgent__c,
                                                ProviderReference__c,
                                                (SELECT
                                                    Name,
                                                    Status__c,
                                                    Type__c,
                                                    Stakeholder__c,
                                                    Stakeholder__r.Name,
                                                    Description__c,
                                                    StartDate__c
                                                FROM Services__r)
                                            FROM Order
                                            WHERE Id IN :orderIds
                                            AND CaseNumber__r.GrandAccount__c = 'PLYO'
            ];

            if(!listOrders.isEmpty()){
                switch on type {
                        when 'AL' {
                            createEncargoPelayoService(token, listOrders, type);
                        }
                        when else {
                            assignEncargoPelayoService(token, listOrders, type);
                        }
                    }
            }

        } else {
            System.debug('Failed to obtain access token for Pelayo service. Order IDs: ' + String.join(orderIds, ',') + ', Type: ' + type);
        }
    }

    
    /**
    * @description Creates assignment in Pelayo service
    * @author Daniel Flores | 04-03-2026
    * @param token
    * @param listOrders
    * @param type
    */
    public static void createEncargoPelayoService(String token, List<Order> listOrders, String type){

        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        WebServiceUtils__mdt config = [SELECT Endpoint__c, ClientId__c, ClientSecret__c FROM WebServiceUtils__mdt WHERE MasterLabel = 'Update Pelayo Assignment' AND isSandbox__c =:isSandbox LIMIT 1];

        Map<String, String> mapAccountInformation = PelayoOutBoundStrucuture.setMapAccountInformation(listOrders);
        Map<String, List<Order>> groupedCaseOrders = new Map<String, List<Order>>();
        Map<String, Order> mapOrderMatchingForUpdate = new Map<String, Order>();
        Map<String, String> mapCaseMatching = new Map<String, String>();
        Map<String, PelayoOutBoundStrucuture.CaseInfo> groupedCaseInfo = new Map<String, PelayoOutBoundStrucuture.CaseInfo>();

        for (Order encargo : listOrders) {
            if(String.isNotBlank(encargo.CaseNumber__c)){

                if (!groupedCaseOrders.containsKey(encargo.CaseNumber__c)) {

                    groupedCaseInfo.put(encargo.CaseNumber__c, setCaseInfoFromOrder(encargo));
                    groupedCaseOrders.put(encargo.CaseNumber__c, new List<Order>{encargo});

                } else {
                    groupedCaseOrders.get(encargo.CaseNumber__c).add(encargo);
                }
            }
            mapOrderMatchingForUpdate.put(encargo.OrderNumber, encargo);
            mapCaseMatching.put(encargo.CaseNumber__r.CaseNumber, encargo.CaseNumber__c);
        }

        List<Order> ordersToUpdate = new List<Order>();
        for(String caseNumber : groupedCaseOrders.keySet()){

            String requestBody = PelayoOutBoundStrucuture.createJSON(groupedCaseInfo.get(caseNumber), groupedCaseOrders.get(caseNumber), mapAccountInformation, type);
            System.debug('Request Body (pretty):\n' + debugPrettyPrintJSON(requestBody));

            UpdateAssignmentPelayoResponse serviceResponse = updateAssignmentPelayoService(config.Endpoint__c, token, requestBody);
            if(serviceResponse.success){
                for(EncargoResponse serviceEncargo : serviceResponse.encargos){
                    if(mapOrderMatchingForUpdate.containsKey(serviceEncargo.idEncargoElba)){
                        Order matchEncargo = mapOrderMatchingForUpdate.get(serviceEncargo.idEncargoElba);
                        matchEncargo = setOrderWithResponseInfo(matchEncargo, serviceEncargo);
                        ordersToUpdate.add(matchEncargo);
                        sendResponseEvent(serviceEncargo.success, matchEncargo.Id, serviceEncargo.message);
                    }
                }
            }
            sendResponseEvent(serviceResponse.success, mapCaseMatching.get(serviceResponse.idSiniestroElba), serviceResponse.message);
        }
        if(!ordersToUpdate.isEmpty()){
            OrderTriggerLogic.bypassExternalActions = true;
            update ordersToUpdate;
        }
    }

    
    /**
    * @description Assigns assignment in Pelayo service
    * @author Daniel Flores | 04-03-2026
    * @param token
    * @param listOrders
    * @param type
    */
    public static void assignEncargoPelayoService(String token, List<Order> listOrders, String type){
        if (token == null) {
            token = getToken();
        }
        
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        WebServiceUtils__mdt config = [SELECT Endpoint__c, ClientId__c, ClientSecret__c FROM WebServiceUtils__mdt WHERE MasterLabel = 'Update Pelayo Assignment' AND isSandbox__c =:isSandbox LIMIT 1];

        Map<String, String> mapAccountInformation = PelayoOutBoundStrucuture.setMapAccountInformation(listOrders);
        List<Order> ordersToUpdate = new List<Order>();

        for(Order encargo : listOrders){

            String requestBody = PelayoOutBoundStrucuture.createJSON(setCaseInfoFromOrder(encargo), new List<Order>{encargo}, mapAccountInformation, type);
            System.debug('Request Body (pretty):\n' + debugPrettyPrintJSON(requestBody));

            UpdateAssignmentPelayoResponse serviceResponse = updateAssignmentPelayoService(config.Endpoint__c, token, requestBody);
            if(serviceResponse.message.startsWith('Exception')){
                encargo.LastIntegration__c = 'IntegrationsExtensionClass/assignEncargoPelayoService/type' + type + '/orderId' + encargo.Id;
            }else{
                encargo.LastIntegration__c = null;
            }
            if(serviceResponse.success){
                for(EncargoResponse serviceEncargo : serviceResponse.encargos){
                    ordersToUpdate.add(setOrderWithResponseInfo(encargo, serviceEncargo));
                    sendResponseEvent(serviceEncargo.success, encargo.Id, serviceEncargo.message);
                }
            }
            sendResponseEvent(serviceResponse.success, encargo.CaseNumber__c, serviceResponse.message);
        }

        if(!ordersToUpdate.isEmpty()){
            OrderTriggerLogic.bypassExternalActions = true;
            update ordersToUpdate;
        }
    }

    /**
    * @description Updates the assignment in the Pelayo service.
    * @author Afonso Duque | 23-02-2026
    * @param  endpoint
    * @param  token
    * @param  requestBody
    **/
    public static UpdateAssignmentPelayoResponse updateAssignmentPelayoService(String endpoint, String token, String requestBody){

        UpdateAssignmentPelayoResponse serviceResponse = new UpdateAssignmentPelayoResponse();

        try {
            endpoint = normalizePelayoEndpoint(endpoint);

            HttpRequest request = HttpRequestFactory.createHttpRequest(
                'PUT',
                endpoint,
                new Map<String, String>{
                    'Accept' => 'application/json',
                    'Content-Type' => 'application/json',
                    'Authorization' => token
                },
                requestBody
            );

            Http http = new Http();
            HttpResponse response = http.send(request);

            if(response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                serviceResponse = (UpdateAssignmentPelayoResponse) JSON.deserialize(response.getBody(), UpdateAssignmentPelayoResponse.class);
                System.debug('Successfully updated assignment in Pelayo service. Response: ' + response.getBody());
            } else {
                serviceResponse = new UpdateAssignmentPelayoResponse(false, 'Failed to update assignment in Pelayo service. Status Code: ' + response.getStatusCode());
                System.debug('Failed to update assignment in Pelayo service. Status Code: ' + response.getStatusCode() + ', Response: ' + response.getBody());
            }

        } catch (Exception e) {
            serviceResponse = new UpdateAssignmentPelayoResponse(false, 'Exception while calling Pelayo service: ' + e.getMessage());
        }

        return serviceResponse;
    }

    /**
    * @description Sets the CaseInfo object from an Order record.
    * @author Afonso Duque | 26-02-2026
    * @param  recordOrder
    * @return PelayoOutBoundStrucuture.CaseInfo
    **/
    public static PelayoOutBoundStrucuture.CaseInfo setCaseInfoFromOrder(Order recordOrder){
        PelayoOutBoundStrucuture.CaseInfo caseInfo = new PelayoOutBoundStrucuture.CaseInfo();
        caseInfo.caseNumber = recordOrder.CaseNumber__r.CaseNumber;
        caseInfo.insurerClaimReference = recordOrder.CaseNumber__r.InsurerClaimReference__c;
        caseInfo.claimsHandlerName = recordOrder.CaseNumber__r.ClaimsHandlerName__c;
        return caseInfo;
    }

    /**
    * @description Sets the Order record with the response information from the Pelayo service.
    * @author Afonso Duque | 26-02-2026
    * @param  recordOrder
    * @param  serviceResponse
    * @return Order
    **/
    public static Order setOrderWithResponseInfo(Order recordOrder, EncargoResponse serviceResponse){
        recordOrder.ChargeIdentifier__c = serviceResponse.idEncargoAseguradora;
        recordOrder.LastIntegrationDateTime__c = System.now();
        recordOrder.LastIntegrationDescription__c = serviceResponse.message;
        recordOrder.LastIntegration__c = '';
        return recordOrder;
    }

    /**
    * @description Sends a response event to the PopUP_Service__e platform event with the given parameters.
    * @author Afonso Duque | 26-02-2026
    * @param  isSuccess
    * @param  recordId
    * @param  message
    **/
    public static void sendResponseEvent(Boolean isSuccess, String recordId, String message) {
        PopUP_Service__e responseEvent = new PopUP_Service__e(
            RecordId__c = recordId,
            Message__c = message,
            Success__c = isSuccess
        );
        Database.SaveResult result = EventBus.publish(responseEvent);
    }

    /**
    * @description Utility method to pretty print a JSON string for debugging purposes.
    * @author Afonso Duque | 26-02-2026
    * @param  jsonString
    * @return String
    **/
    public static String debugPrettyPrintJSON(String jsonString) {
        Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
        return JSON.serializePretty(parsed);
    }

    /**
    * @description Response structure for Pelayo service
    * @author Daniel Flores | 04-03-2026
    */
    public class UpdateAssignmentPelayoResponse {
        public String id;
        public Boolean success;
        public String message;
        public String idSiniestroElba;
        public String idSiniestroAseguradora;
        public List<EncargoResponse> encargos;

        public UpdateAssignmentPelayoResponse() {
            this.success = false;
            this.encargos = new List<EncargoResponse>();
        }

        public UpdateAssignmentPelayoResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
            this.encargos = new List<EncargoResponse>();
        }
    }

    /**
    * @description Assignment response structure for Pelayo service
    * @author Daniel Flores | 04-03-2026
    */
    public class EncargoResponse {
        public String idEncargoElba;
        public String idEncargoAseguradora;
        public Boolean success;
        public String message;
    }
}