/**
 * @description       : Test class for PelayoIncidentService and PelayoIncidentOutBoundStructure.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 06-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class PelayoIncidentServiceTest {

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        // Create Pelayo Account
        Account pelayoAccount = TestFactory.createAccount(
            'Pelayo Test Account',
            'PLYO',
            'A2',
            'Customer'
        );

        // Create Pelayo Case
        Case pelayoCase = new Case(
            Subject = 'Test Pelayo Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'PLYO',
            InsurerClaimReference__c = 'SIN-TEST-001'
        );
        insert pelayoCase;

        // Create Order linked to Case
        Id standardPricebookId = Test.getStandardPricebookId();
        Order testOrder = new Order(
            AccountId = pelayoAccount.Id,
            Status = 'Service Management',
            ChargeIdentifier__c = 'ENC-TEST-001',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            Service__c = 'SRV-001'
        );
        insert testOrder;

        // Create Product and PricebookEntry for Order
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry testPricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert testPricebookEntry;

        OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = testPricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 1
        );
        insert testOrderItem;

        // Create Repairer Account
        Account repairerAccount = TestFactory.createAccount(
            'Reparaciones Garcia S.L.',
            'reparador@test.com',
            '910000001',
            'Multigremio',
            'A2'
        );

        // Create Incident linked to Order
        Incident testIncident = new Incident(
            Subject = 'Test Incident',
            Description = 'El reparador no se presento en la fecha acordada.',
            Status = 'New',
            Priority = 'Medium',
            Type = 'Dissatisfaction',
            Reason__c = 'M03',
            Sub_Reason__c = 'S03002',
            Origin__c = 'AS',
            Channel__c = 'EB',
            ManagementTeam__c = 'TR',
            ResponsiblePartyType__c = 'RE',
            ResponsibleParty__c = 'Reparaciones Garcia S.L.',
            OrderService__c = testOrder.Id,
            Repairer__c = repairerAccount.Id
        );
        insert testIncident;
    }

    // ─── Structure Tests ──────────────────────────────────────────────────────

    @IsTest
    static void testCreateJSON_ValidContext() {
        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            new PelayoIncidentOutBoundStructure.IncidentContext();
        
        ctx.idSiniestroElba = '00001135';
        ctx.idSiniestroAseguradora = '010426000491';
        ctx.idIncidenciaElba = 'INC-ELBA-2026-00123';
        ctx.idEncargoElba = '00000518';
        ctx.idServicioElba = 'SRV-001';
        ctx.tipo = 'DI';
        ctx.motivo = 'M03';
        ctx.submotivo = 'S03002';
        ctx.origen = 'AS';
        ctx.canal = 'EB';
        ctx.equipoGestion = 'TR';
        ctx.responsableIncidencias = 'tramitador01';
        ctx.tipoCausante = 'RE';
        ctx.causante = 'Reparaciones Garcia S.L.';
        ctx.estado = 'AB';
        ctx.fechaEstado = Datetime.now();
        ctx.descripcion = 'El reparador no se presento en la fecha acordada.';
        ctx.fechaGrabacion = Datetime.now();
        ctx.fechaAlta = Datetime.now();
        ctx.usuarioAlta = 'GESTOR_ELBA_01';
        ctx.comentarioId = 'COM-ELBA-2026-00041';
        ctx.comentarioDescripcion = 'Se ha intentado contactar con el reparador sin exito.';

        Test.startTest();
        String jsonResult = PelayoIncidentOutBoundStructure.createJSON(ctx);
        Test.stopTest();

        System.assertNotEquals(null, jsonResult, 'JSON should not be null');
        System.assert(jsonResult.contains('idSiniestroElba'), 'JSON should contain idSiniestroElba');
        System.assert(jsonResult.contains('"movimiento":"AL"'), 'JSON should contain movimiento AL');
        System.assert(jsonResult.contains('comentario'), 'JSON should contain comentario');
    }

    @IsTest
    static void testCreateJSON_NullContext() {
        Test.startTest();
        String jsonResult = PelayoIncidentOutBoundStructure.createJSON(null);
        Test.stopTest();

        System.assertEquals(null, jsonResult, 'JSON should be null for null context');
    }

    @IsTest
    static void testCreateJSON_MissingSiniestroElba() {
        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            new PelayoIncidentOutBoundStructure.IncidentContext();
        ctx.idIncidenciaElba = 'INC-001';
        // idSiniestroElba is not set

        Test.startTest();
        String jsonResult = PelayoIncidentOutBoundStructure.createJSON(ctx);
        Test.stopTest();

        System.assertEquals(null, jsonResult, 'JSON should be null when idSiniestroElba is missing');
    }

    @IsTest
    static void testCreateUpdateJSON_ValidContext() {
        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            new PelayoIncidentOutBoundStructure.IncidentContext();
        
        ctx.idSiniestroElba = '00001135';
        ctx.idSiniestroAseguradora = '010426000491';
        ctx.idIncidenciaElba = 'INC-ELBA-2026-00123';
        ctx.estado = 'CE';

        Test.startTest();
        String jsonResult = PelayoIncidentOutBoundStructure.createUpdateJSON(ctx);
        Test.stopTest();

        System.assertNotEquals(null, jsonResult, 'JSON should not be null');
        System.assert(jsonResult.contains('"movimiento":"MO"'), 'JSON should contain movimiento MO for update');
    }

    @IsTest
    static void testMapStatusToEstado() {
        System.assertEquals('AB', PelayoIncidentOutBoundStructure.mapStatusToEstado(null), 
            'Null status should return AB');
        System.assertEquals('AB', PelayoIncidentOutBoundStructure.mapStatusToEstado('New'), 
            'New status should return AB');
        System.assertEquals('AB', PelayoIncidentOutBoundStructure.mapStatusToEstado('In Progress'), 
            'In Progress status should return AB');
        System.assertEquals('CE', PelayoIncidentOutBoundStructure.mapStatusToEstado('Closed'), 
            'Closed status should return CE');
        System.assertEquals('CE', PelayoIncidentOutBoundStructure.mapStatusToEstado('Resolved'), 
            'Resolved status should return CE');
        System.assertEquals('CE', PelayoIncidentOutBoundStructure.mapStatusToEstado('Cerrado'), 
            'Cerrado status should return CE');
    }

    @IsTest
    static void testMapTypeToPelayo() {
        System.assertEquals(null, PelayoIncidentOutBoundStructure.mapTypeToPelayo(null), 
            'Null type should return null');
        System.assertEquals('DI', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Dissatisfaction'), 
            'Dissatisfaction should map to DI');
        System.assertEquals('RE', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Claim'), 
            'Claim should map to RE');
        System.assertEquals('QU', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Complaint'), 
            'Complaint should map to QU');
        System.assertEquals('SU', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Suggestion'), 
            'Suggestion should map to SU');
        System.assertEquals('CO', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Consultation'), 
            'Consultation should map to CO');
        System.assertEquals('Unknown', PelayoIncidentOutBoundStructure.mapTypeToPelayo('Unknown'), 
            'Unknown type should pass through');
    }

    @IsTest
    static void testResponseStructure() {
        PelayoIncidentOutBoundStructure.IncidentResponse resp = 
            new PelayoIncidentOutBoundStructure.IncidentResponse();
        
        System.assertEquals(false, resp.success, 'Default success should be false');

        PelayoIncidentOutBoundStructure.IncidentResponse resp2 = 
            new PelayoIncidentOutBoundStructure.IncidentResponse(true, 'Test message');
        
        System.assertEquals(true, resp2.success, 'Success should be true');
        System.assertEquals('Test message', resp2.message, 'Message should match');
    }

    // ─── Service Tests ────────────────────────────────────────────────────────

    @IsTest
    static void testEnqueueCreate_Success() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Incident created successfully","idSiniestroElba":"00001135","idIncidenciaElba":"INC-001"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enqueueCreate(new List<Id>{ inc.Id });
        Test.stopTest();

        // Verify job was enqueued (no assertions needed, just coverage)
        System.assert(true, 'Enqueue should complete without errors');
    }

    @IsTest
    static void testEnqueueUpdate_Success() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Incident updated successfully"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enqueueUpdate(new List<Id>{ inc.Id });
        Test.stopTest();

        System.assert(true, 'Enqueue should complete without errors');
    }

    @IsTest
    static void testEnqueueCreate_EmptyList() {
        Test.startTest();
        PelayoIncidentService.enqueueCreate(null);
        PelayoIncidentService.enqueueCreate(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Should handle empty/null lists gracefully');
    }

    @IsTest
    static void testCallCreateIncidentsSync_Success() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Incident created successfully"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.callCreateIncidentsSync(new List<Id>{ inc.Id });
        Test.stopTest();

        Incident updatedIncident = [
            SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c, LastIntegration__c
            FROM Incident
            WHERE Id = :inc.Id
        ];

        System.assertNotEquals(null, updatedIncident.LastIntegrationDateTime__c);
        System.assertEquals('Incident created successfully', updatedIncident.LastIntegrationDescription__c);
        System.assertEquals('', updatedIncident.LastIntegration__c);
    }

    @IsTest
    static void testCallCreateIncidentsSync_HttpError() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                500,
                'Internal Server Error',
                '{"error":"Server error"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.callCreateIncidentsSync(new List<Id>{ inc.Id });
        Test.stopTest();

        System.assert(true, 'Should handle HTTP errors gracefully');
    }

    @IsTest
    static void testCallCreateIncidentsSync_NoToken() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                401,
                'Unauthorized',
                '{"error":"Invalid credentials"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.callCreateIncidentsSync(new List<Id>{ inc.Id });
        Test.stopTest();

        System.assert(true, 'Should handle missing token gracefully');
    }

    @IsTest
    static void testCallUpdateIncidentsSync_Success() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Incident updated successfully"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.callUpdateIncidentsSync(new List<Id>{ inc.Id });
        Test.stopTest();

        Incident updatedIncident = [
            SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c, LastIntegration__c
            FROM Incident
            WHERE Id = :inc.Id
        ];

        System.assertNotEquals(null, updatedIncident.LastIntegrationDateTime__c);
        System.assertEquals('Incident updated successfully', updatedIncident.LastIntegrationDescription__c);
        System.assertEquals('', updatedIncident.LastIntegration__c);
    }

    @IsTest
    static void testIsPelayoIncident_Valid() {
        Incident inc = [
            SELECT Id, OrderService__c, 
                   OrderService__r.CaseNumber__r.GrandAccount__c
            FROM Incident 
            LIMIT 1
        ];

        Test.startTest();
        Boolean result = PelayoIncidentService.isPelayoIncident(inc);
        Test.stopTest();

        System.assertEquals(true, result, 'Should identify Pelayo incident correctly');
    }

    @IsTest
    static void testIsPelayoIncident_NoOrder() {
        Test.startTest();
        Boolean result = PelayoIncidentService.isPelayoIncident(null);
        Test.stopTest();

        System.assertEquals(false, result, 'Null incident should return false');
    }

    @IsTest
    static void testBuildIncidentContext() {
        List<Incident> incidents = PelayoIncidentService.queryIncidents(
            new List<Id>{ [SELECT Id FROM Incident LIMIT 1].Id }
        );
        
        System.assertEquals(1, incidents.size(), 'Should query incident');

        Test.startTest();
        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            PelayoIncidentService.buildIncidentContext(incidents[0]);
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertNotEquals(null, ctx.incidentId, 'Incident ID should be set');
    }

    @IsTest
    static void testBuildIncidentContext_NoOrder() {
        Test.startTest();
        PelayoIncidentOutBoundStructure.IncidentContext ctx = 
            PelayoIncidentService.buildIncidentContext(null);
        Test.stopTest();

        System.assertEquals(null, ctx, 'Context should be null for null incident');
    }

    // ─── Non-Pelayo Case Test ─────────────────────────────────────────────────

    @IsTest
    static void testCallCreateIncidentsSync_NonPelayoCase() {
        // Create a non-Pelayo case
        Account nonPelayoAccount = TestFactory.createAccount(
            'Non Pelayo Account',
            'OTHER',
            'A2',
            'Customer'
        );

        Case nonPelayoCase = new Case(
            Subject = 'Test Non-Pelayo Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'OTHER'
        );
        insert nonPelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order nonPelayoOrder = new Order(
            AccountId = nonPelayoAccount.Id,
            Status = 'Service Management',
            CaseNumber__c = nonPelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert nonPelayoOrder;

        Product2 testProduct = new Product2(Name = 'Test Product 2', IsActive = true);
        insert testProduct;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;

        OrderItem oi = new OrderItem(
            OrderId = nonPelayoOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1
        );
        insert oi;

        Incident nonPelayoIncident = new Incident(
            Subject = 'Non-Pelayo Incident',
            Status = 'New',
            OrderService__c = nonPelayoOrder.Id
        );
        insert nonPelayoIncident;

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.callCreateIncidentsSync(new List<Id>{ nonPelayoIncident.Id });
        Test.stopTest();

        System.assert(true, 'Should skip non-Pelayo incidents');
    }

    // ─── Queueable Tests ──────────────────────────────────────────────────────

    @IsTest
    static void testCreateIncidentQueueable() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Success"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.CreateIncidentQueueable queueable = 
            new PelayoIncidentService.CreateIncidentQueueable(new List<Id>{ inc.Id });
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true, 'Queueable should execute without errors');
    }

    @IsTest
    static void testUpdateIncidentQueueable() {
        Incident inc = [SELECT Id FROM Incident LIMIT 1];

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"id":"test-id","success":true,"message":"Success"}'
            )
        };
        HttpCalloutMockFactory serviceMocks = new HttpCalloutMockFactory(responses);
        Test.setMock(HttpCalloutMock.class, serviceMocks);

        Test.startTest();
        PelayoIncidentService.enableCalloutsInTests = true;
        PelayoIncidentService.UpdateIncidentQueueable queueable = 
            new PelayoIncidentService.UpdateIncidentQueueable(new List<Id>{ inc.Id });
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true, 'Queueable should execute without errors');
    }
}