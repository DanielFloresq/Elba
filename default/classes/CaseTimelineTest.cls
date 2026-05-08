/**
 * @description       : Test class for CaseTimelineController timeline data retrieval
 * @author            : Daniel Flores
 * @group             :
 * @last modified on  : 10-02-2026
 * @last modified by  : Afonso Duque
**/
@isTest
public with sharing class CaseTimelineTest {

    /**
     * @description Tests getHistoryDisplayValue with various valid and invalid sObject/field combinations
     */
    @isTest
    public static void testGetHistoryDisplayValue() {

        Test.startTest();

        CaseTimelineController.getHistoryDisplayValue('Order', 'Status', 'Open');
        CaseTimelineController.getHistoryDisplayValue('Order', 'Guild__c', 'ABOGADO');
        CaseTimelineController.getHistoryDisplayValue('Order', 'Status', null);
        CaseTimelineController.getHistoryDisplayValue('', 'Status', 'Open');
        CaseTimelineController.getHistoryDisplayValue('OrderError', 'Status', 'Open');
        CaseTimelineController.getHistoryDisplayValue('Order', 'StatusError', 'Open');

        Test.stopTest();
    }

    /**
     * @description Tests getPicklistLabel with valid and invalid sObject/field combinations
     */
    @isTest
    public static void testGetPicklistLabel() {
        Test.startTest();
        CaseTimelineController.getPicklistLabel('Order', 'Type', 'Claim');
        CaseTimelineController.getPicklistLabel('OrderError', 'Type', 'Claim');
        CaseTimelineController.getPicklistLabel('Order', 'TypeError', 'Claim');
        Test.stopTest();
    }

    /**
     * @description Tests timeline activity retrieval with bookmarked filter and verifies title, header and body field rendering for multiple sObject types
     */
    @isTest
    public static void test_timeline() {

        Case ca = new Case();
        ca.Type = 'Sinistro';
        ca.Subject = 'Teste';
        ca.Status = 'New';
        ca.Origin = 'Phone';
        ca.Favorites__c = '00a2z000000BC9YAAW;a0c2z000001iZkRAAU';
        insert ca;

        Account ac = new Account();
        ac.Name = 'teste2';
        insert ac;

        List<String> lst = new List<String>();
        lst.add('Order');
        lst.add('Favoritos');
        lst.add('CaseHistory');
        lst.add('Comments__c');
        lst.add('Event');
        lst.add('Task');
        lst.add('EmailMessage');
        lst.add('ProcessInstanceHistory');
        lst.add('Stakeholders__c');
        List<String> lsts = new List<String>();
        lsts.add('Favorites');

        CaseTimelineController.Filter fils = new CaseTimelineController.Filter();
        fils.selectedObjets = lsts;
        fils.endDate= '2022-04-27T19:49:23.899Z';
        fils.startDate='2022-04-27T19:49:23.899Z';

        CaseTimelineController tim = new CaseTimelineController();
        CaseTimelineController.Item ite = new CaseTimelineController.Item();
        CaseHistory c = new CaseHistory();
        Order o = new Order();
        ProcessInstanceHistory p = new ProcessInstanceHistory();
        EmailMessage e = new EmailMessage();
        Task tk = new Task();
        Event ev = new Event();
        ProcessInstanceHistory ph = new ProcessInstanceHistory();
        CaseComment cc = new CaseComment();
        e.HtmlBody='------------';
        e.Subject = 'Teste';
        ev.Subject = 'Teste';
        ev.WhatId = ca.Id;
        ev.StartDateTime=System.now();
        ev.DurationInMinutes = 60;
        ev.EndDateTime=System.now().addMinutes(60);
        o.AccountId = ac.Id;
        o.EffectiveDate= date.valueOf('2023-04-19');
        o.Status= 'Draft';
        o.CaseNumber__c = ca.Id;
        insert o;
        tk.Subject = 'Teste';
        tk.WhatId = ca.Id;
        insert tk;

        /*
        StakeholderContacts__c shc = new StakeholderContacts__c();
        shc.Order__c = o.Id;
        insert shc;
        */


        cc.ParentId = ca.Id;
        insert cc;

        Stakeholders__c sh = new Stakeholders__c(
            Name= 'test',
            Designation__c='Policyholder',
            Description__c='test',
            Case__c = ca.Id
        );
        insert sh;
        CaseTimelineController.getActivities(ca.Id, fils);
        CaseTimelineController.getTitle('CaseHistory', c);
        CaseTimelineController.getTitle('Order', o);
        CaseTimelineController.getTitle('EmailMessage', e);
        CaseTimelineController.getTitle('Task', tk);
        CaseTimelineController.getTitle('Event', ev);
        CaseTimelineController.getTitle('CaseComment', cc);
        CaseTimelineController.getTitle('Stakeholders__c', sh);
        CaseTimelineController.getTitle('ProcessInstanceHistory', ph);
        CaseTimelineController.getHeaderBody('Order', o);
        CaseTimelineController.getHeaderBody('CaseHistory', c);
        CaseTimelineController.getBodyFields('CaseHistory', c);
        CaseTimelineController.getBodyFields('Order', o);
        CaseTimelineController.getBodyFields('EmailMessage', e);
        CaseTimelineController.getBodyFields('Task', tk);
        CaseTimelineController.getBodyFields('Event', ev);
        CaseTimelineController.getBodyFields('CaseComment', cc);
        CaseTimelineController.getBodyFields('ProcessInstanceHistory', ph);
        CaseTimelineController.getBodyFields('Stakeholders__c', sh);
        CaseTimelineController.getBookMarked(ca.Id);
        CaseTimelineController.getUsers();
        CaseTimelineController.getApprovals(ca.Id);
        CaseTimelineController.getEmails(ca.Id);
        CaseTimelineController.getTasks(ca.Id);
        CaseTimelineController.getEvents(ca.Id);
        CaseTimelineController.getCaseStatusHistory(ca.Id);
        CaseTimelineController.Item ites = new CaseTimelineController.Item('EmailMessage', e, System.now(), 'teste', false, false);
        CaseTimelineController.Field fid = new CaseTimelineController.Field('teste2','asfsdf','trteter','asdfasd', 'asasdsfsd');
        CaseTimelineController.filter filt = new CaseTimelineController.filter();
    }
    /**
     * @description Tests timeline activity retrieval with a broader set of selected objects and non-bookmarked filter
     */
    @isTest
    public static void test_timeline2() {
        Case ca = new Case();
        ca.Type = 'Sinistro';
        ca.Subject = 'Teste';
        ca.Status = 'New';
        ca.Origin = 'Phone';
        ca.Favorites__c = '00a2z000000BC9YAAW;a0c2z000001iZkRAAU';
        insert ca;

        Account ac = new Account();
        ac.Name = 'teste2';
        insert ac;
        List<String> lst = new List<String>();
        lst.add('Order');
        lst.add('Favoritos');
        lst.add('CaseHistory');
        lst.add('Comentario__c');
        lst.add('CoberturaDoProcesso__c');
        lst.add('Provisoes__c');
        lst.add('Estados_do_Processo__c');
        lst.add('MessagingSession');
        lst.add('CaseComments');
        lst.add('Event');
        lst.add('Task');
        lst.add('EmailMessage');
        lst.add('ProcessInstanceHistory');
        lst.add('AditamentoComentario__c');

        List<String> lsts = new List<String>();
        lsts.add('Favoritos');
        CaseTimelineController.Filter fils = new CaseTimelineController.Filter();

        fils.selectedObjets = lsts;
        fils.endDate= '2022-04-27T19:49:23.899Z';
        fils.startDate='2022-04-27T19:49:23.899Z';

        CaseTimelineController tim = new CaseTimelineController();
        CaseTimelineController.Filter fil = new CaseTimelineController.Filter();
        CaseTimelineController.Item ite = new CaseTimelineController.Item();
        fil.selectedObjets = lst;
        fil.endDate= '2022-04-27T19:49:23.899Z';
        fil.startDate='2022-04-27T19:49:23.899Z';

        CaseHistory c = new CaseHistory();
        ProcessInstanceHistory p = new ProcessInstanceHistory();
        ProcessInstanceHistory ph = new ProcessInstanceHistory();
        EmailMessage e = new EmailMessage();
        e.HtmlBody='------------';
        e.Subject = 'Teste';
        Order o = new Order();
        o.AccountId = ac.Id;
        o.EffectiveDate= date.valueOf('2023-04-19');
        o.Status= 'Draft';
        o.CaseNumber__c = ca.Id;
        insert o;
        Event ev = new Event();
        ev.Subject = 'Teste';
        ev.WhatId = ca.Id;
        ev.StartDateTime=System.now();
        ev.DurationInMinutes = 60;
        ev.EndDateTime=System.now().addMinutes(60);
        Task tk = new Task();
        tk.WhatId = ca.Id;
        tk.Subject = 'teste';
        insert tk;
        CaseComment cc = new CaseComment();
        cc.ParentId = ca.Id;
        insert cc;
        CaseTimelineController.getActivities(ca.Id, fil);
    }

    /**
     * @description Tests title and body field generation for OrderHistory, Service__History, CaseHistory and Incident sObject types
     */
    @isTest
    public static void test_history_titles_and_bodies() {
        Account ac = new Account(Name = 'Acc');
        insert ac;

        Case ca = new Case(
            Type = 'Sinistro',
            Subject = 'Teste',
            Status = 'New',
            Origin = 'Phone'
        );
        insert ca;

        Order ord = new Order(
            AccountId = ac.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            CaseNumber__c = ca.Id
        );
        insert ord;

        /*
        StakeholderContacts__c shc = new StakeholderContacts__c(
            Order__c = ord.Id
        );
        insert shc;

        StakeholderContacts__c shcWithOrder = [
            SELECT Id, Name, Order__c, Order__r.OrderNumber
            FROM StakeholderContacts__c
            WHERE Id = :shc.Id
            LIMIT 1
        ];
        CaseTimelineController.stakeholderContactsById = new Map<String, StakeholderContacts__c>{
            shcWithOrder.Id => shcWithOrder
        };
        */

        OrderHistory oh = (OrderHistory) Schema.getGlobalDescribe().get('OrderHistory').newSObject();
        CaseTimelineController.getTitle('OrderHistory', oh);
        CaseTimelineController.getBodyFields('OrderHistory', oh);

        OrderHistory ohCreated = (OrderHistory) Schema.getGlobalDescribe().get('OrderHistory').newSObject();
        CaseTimelineController.getTitle('OrderHistory', ohCreated);

        Service__History shh = (Service__History) Schema.getGlobalDescribe().get('Service__History').newSObject();
        CaseTimelineController.getTitle('Service__History', shh);
        CaseTimelineController.getBodyFields('Service__History', shh);

        Service__History shhCreated = (Service__History) Schema.getGlobalDescribe().get('Service__History').newSObject();
        CaseTimelineController.getTitle('Service__History', shhCreated);

        CaseHistory ch = (CaseHistory) Schema.getGlobalDescribe().get('CaseHistory').newSObject();
        CaseTimelineController.getHeaderBody('CaseHistory', ch);

        Incident inc = (Incident) Schema.getGlobalDescribe().get('Incident').newSObject();
        inc.put('Subject', 'Inc');
        CaseTimelineController.getTitle('Incident', inc);
        CaseTimelineController.getBodyFields('Incident', inc);
    }

    /**
     * @description Tests full activity coverage including all timeline object types with real data and date-range filters
     */
    @isTest
    public static void test_full_activity_coverage() {
        Account ac = new Account(Name = 'Acc Full');
        insert ac;

        Case ca = new Case(
            Type = 'Sinistro',
            Subject = 'Teste Full',
            Status = 'New',
            Origin = 'Phone'
        );
        insert ca;

        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 prod = new Product2(
            Name = 'Produto Teste',
            IsActive = true
        );
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId = ac.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId,
            CaseNumber__c = ca.Id
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 1,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        Stakeholders__c sh = new Stakeholders__c(
            Name = 'Stakeholder',
            Designation__c = 'Policyholder',
            Description__c = 'Desc',
            Case__c = ca.Id
        );
        insert sh;

        /*
        StakeholderContacts__c shc = new StakeholderContacts__c(
            Order__c = ord.Id
        );
        insert shc;

        shc.put('mkisId__c', 'MK-001');
        update shc;
        */

        ord.Status = 'Primer Avance';
        update ord;


        Comments__c com = new Comments__c(
            Case__c = ca.Id,
            Comment__c = 'Comentario'
        );
        insert com;

        Event ev = new Event(
            Subject = 'Evento',
            WhatId = ca.Id,
            StartDateTime = System.now(),
            DurationInMinutes = 60,
            EndDateTime = System.now().addMinutes(60)
        );
        insert ev;

        Task tk = new Task(
            Subject = 'Tarefa',
            WhatId = ca.Id
        );
        insert tk;

        EmailMessage em = new EmailMessage(
            ParentId = ca.Id,
            Subject = 'Assunto',
            HtmlBody = 'Corpo --------------- ' + Label.Originalmessage + ' --------------- Resto',
            Incoming = true,
            ToAddress = 'to@test.com',
            FromAddress = 'from@test.com'
        );
        insert em;

        EmailMessage em2 = new EmailMessage(
            ParentId = ca.Id,
            Subject = 'Assunto 2',
            HtmlBody = 'Sem separador',
            Incoming = false,
            ToAddress = 'to2@test.com',
            FromAddress = 'from2@test.com'
        );
        insert em2;

        Incident inc = new Incident(
            Subject = 'Incidente',
            NestedCaseID__c = ca.Id,
            OrderService__c = ord.Id
        );
        insert inc;

        CaseTimelineController.Filter fil = new CaseTimelineController.Filter();
        fil.selectedObjets = new List<String>{
            'Favorites',
            'CaseHistory',
            'OrderHistory',
            'Service__History',
            // 'StakeholderContacts__c',
            'Incident',
            'Comments__c',
            'Event',
            'Task',
            'EmailMessage',
            'ProcessInstanceHistory',
            'Order',
            'Stakeholders__c'
        };
        fil.startDate = String.valueOf(Date.today().addDays(-1));
        fil.endDate = String.valueOf(Date.today().addDays(1));

        CaseTimelineController.getActivities(ca.Id, fil);
        /*
        CaseTimelineController.getStakeholdersContact(ca.Id);
        CaseTimelineController.getStakeholdersContacts(ca.Id);
        */
        CaseTimelineController.getServicos(ca.Id);
        CaseTimelineController.getIncidencias(ca.Id);
        CaseTimelineController.getComments(ca.Id);
        CaseTimelineController.getEvents(ca.Id);
        CaseTimelineController.getTasks(ca.Id);
        CaseTimelineController.getEmails(ca.Id);

        List<OrderHistory> orderHistories = [SELECT Id, Field, OldValue, NewValue, Order.OrderNumber FROM OrderHistory WHERE OrderId = :ord.Id LIMIT 1];
        if (!orderHistories.isEmpty()) {
            CaseTimelineController.getTitle('OrderHistory', orderHistories[0]);
            CaseTimelineController.getBodyFields('OrderHistory', orderHistories[0]);
            CaseTimelineController.getHeaderBody('OrderHistory', orderHistories[0]);
        }
    }

    /**
     * @description Creates shared test data including a Case with Favorites and an Account
     */
    @TestSetup
    static void makeData(){
        Case c = new Case();
        c.Type = 'Sinistro';
        c.Favorites__c = 'asfasf;asfasdfs';
        insert c;

        Account ac = new Account();
        ac.Name = 'teste';
        insert ac;
    }
}