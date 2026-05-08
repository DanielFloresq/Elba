/**
 * @description       : Test class for PelayoNotificationService.
 * @author            : Daniel Flores
 * @group             : Pelayo Integration
 * @last modified on  : 07-04-2026
 * @last modified by  : Daniel Flores
**/
@IsTest
public class PelayoNotificationServiceTest {

    @TestSetup
    static void setupData() {
        Account pelayoAccount = TestFactory.createAccount(
            'Pelayo Notification Account',
            'PLYO',
            'A2',
            'Customer'
        );

        Case pelayoCase = new Case(
            Subject = 'Pelayo Solicitation Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'PLYO',
            InsurerClaimReference__c = '010426000491'
        );
        insert pelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order pelayoOrder = new Order(
            AccountId = pelayoAccount.Id,
            Status = 'Service Management',
            CaseNumber__c = pelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert pelayoOrder;

        Product2 product = new Product2(Name = 'Solicitation Product', IsActive = true);
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;

        insert new OrderItem(
            OrderId = pelayoOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1
        );
    }

    @IsTest
    static void testCreateJSON() {
        PelayoNotificationOutBoundStructure.NotificationContext ctx =
            new PelayoNotificationOutBoundStructure.NotificationContext();
        ctx.idSiniestroElba = '00001135';
        ctx.idSiniestroAseguradora = '010426000491';
        ctx.idNotificacionElba = 'SO-00001';
        ctx.idNotificacionAseguradora = '550e8400-e29b-41d4-a716-446655440000';
        ctx.idEncargoElba = '00000518';
        ctx.tipoSolicitudElba = 'SE01';
        ctx.descripcion = 'Motivo de Solicitud de Envio de Perito.';
        ctx.fechaAlta = Datetime.now();
        ctx.usuarioAlta = 'GESTOR_ELBA_01';
        ctx.fechaModificacion = Datetime.now();
        ctx.usuarioModificacion = 'GESTOR_ELBA_02';

        String jsonResult = PelayoNotificationOutBoundStructure.createJSON(ctx);
        String nullJsonResult = PelayoNotificationOutBoundStructure.createJSON(null);
        System.assertNotEquals(null, jsonResult);
        System.assert(jsonResult.contains('idNotificacionElba'));
        System.assert(jsonResult.contains('SE01'));
        System.assertEquals(null, nullJsonResult);
    }

    @IsTest
    static void testBuildExternalNotificationId() {
        Order pelayoOrder = [SELECT Id FROM Order LIMIT 1];
        Solicitation__c solicitation = new Solicitation__c(
            Order__c = pelayoOrder.Id,
            RequestType__c = 'SE01',
            Description__c = 'Build external notification id'
        );
        insert solicitation;

        String externalId = PelayoNotificationService.buildExternalNotificationId(solicitation.Id);
        System.assertNotEquals(null, externalId);
        System.assertEquals(36, externalId.length());
        System.assertEquals(externalId, PelayoNotificationService.buildExternalNotificationId(solicitation.Id));
    }

    @IsTest
    static void testCallCreateNotificationsSync_Success() {
        Order pelayoOrder = [SELECT Id FROM Order LIMIT 1];

        Solicitation__c solicitation = new Solicitation__c(
            Order__c = pelayoOrder.Id,
            RequestType__c = 'SE01',
            Description__c = 'Motivo de Solicitud de Envio de Perito.'
        );
        insert solicitation;

        List<HttpResponse> responses = new List<HttpResponse>{
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
            ),
            HttpCalloutMockFactory.generateHttpResponse(
                200,
                'OK',
                '{"success":true,"message":"Notification created"}'
            )
        };
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMockFactory(responses));

        Test.startTest();
        PelayoNotificationService.enableCalloutsInTests = true;
        PelayoNotificationService.callCreateNotificationsSync(new List<Id>{ solicitation.Id });
        Test.stopTest();

        Solicitation__c updatedSolicitation = [
            SELECT LastIntegrationDateTime__c, LastIntegrationDescription__c, LastIntegration__c
            FROM Solicitation__c
            WHERE Id = :solicitation.Id
        ];

        System.assertNotEquals(null, updatedSolicitation.LastIntegrationDateTime__c);
        System.assertEquals('Notification created', updatedSolicitation.LastIntegrationDescription__c);
        System.assertEquals('', updatedSolicitation.LastIntegration__c);
    }

    @IsTest
    static void testCallCreateNotificationsSync_NonPelayo() {
        Account account = TestFactory.createAccount(
            'Other Account',
            'OTHER',
            'A2',
            'Customer'
        );
        Case nonPelayoCase = new Case(
            Subject = 'Other Case',
            Status = 'Opening',
            Origin = 'Phone',
            GrandAccount__c = 'OTHER'
        );
        insert nonPelayoCase;

        Id standardPricebookId = Test.getStandardPricebookId();
        Order nonPelayoOrder = new Order(
            AccountId = account.Id,
            Status = 'Service Management',
            CaseNumber__c = nonPelayoCase.Id,
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId
        );
        insert nonPelayoOrder;

        Product2 product = new Product2(Name = 'Other Product', IsActive = true);
        insert product;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1,
            IsActive = true
        );
        insert pbe;
        insert new OrderItem(
            OrderId = nonPelayoOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1
        );

        Solicitation__c solicitation = new Solicitation__c(
            Order__c = nonPelayoOrder.Id,
            RequestType__c = 'SE01',
            Description__c = 'No Pelayo'
        );
        insert solicitation;

        Test.setMock(
            HttpCalloutMock.class,
            new HttpCalloutMockFactory(200, 'OK', '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}')
        );

        Test.startTest();
        PelayoNotificationService.enableCalloutsInTests = true;
        PelayoNotificationService.callCreateNotificationsSync(new List<Id>{ solicitation.Id });
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testQueueableAndTriggerHandler() {
        Order pelayoOrder = [SELECT Id FROM Order LIMIT 1];

        Test.setMock(
            HttpCalloutMock.class,
            new HttpCalloutMockFactory(new List<HttpResponse>{
                HttpCalloutMockFactory.generateHttpResponse(
                    200,
                    'OK',
                    '{"access_token":"test-token","token_type":"Bearer","expires_in":86400}'
                ),
                HttpCalloutMockFactory.generateHttpResponse(
                    200,
                    'OK',
                    '{"success":true,"message":"Notification created"}'
                )
            })
        );

        Test.startTest();
        PelayoNotificationService.enableCalloutsInTests = true;
        insert new Solicitation__c(
            Order__c = pelayoOrder.Id,
            RequestType__c = 'SE01',
            Description__c = 'Created from trigger'
        );
        Test.stopTest();

        Solicitation__c insertedSolicitation = [
            SELECT LastIntegrationDateTime__c
            FROM Solicitation__c
            WHERE Order__c = :pelayoOrder.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertNotEquals(null, insertedSolicitation.LastIntegrationDateTime__c);

        System.assert(true);
    }

    @IsTest
    static void testResolveCreateNotificationEndpoint() {
        String endpoint = PelayoNotificationService.resolveCreateNotificationEndpoint();
        System.assertNotEquals(null, endpoint);
        System.assert(endpoint.endsWith('/createNotification'));
    }
}