global class VehicleOrderBatch implements Database.Batchable<sObject> {
 
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Status__c, Vehicle__c FROM Order__c WHERE Status__c = 'Pending'
        ]);
    }
    global void execute(Database.BatchableContext bc, List<Order__c> orderList) {
        Set<Id> vehicleIds = new Set<Id>();
        for (Order__c order : orderList) {
            if (order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
            }
        }
 
        if (!vehicleIds.isEmpty()) {
            Map<Id, Vechcle__c> vehicleStockMap = new Map<Id, Vechcle__c>(
                [SELECT Id, Stock_Quantity__c FROM Vechcle__c WHERE Id IN :vehicleIds]
            );
 
            List<Order__c> ordersToUpdate = new List<Order__c>();
            List<Vechcle__c> vehiclesToUpdate = new List<Vechcle__c>();
 
            for (Order__c order : orderList) {
                Vechcle__c vehicle = vehicleStockMap.get(order.Vehicle__c);
                if (vehicle != null && vehicle.Stock_Quantity__c > 0) {
                    order.Status__c = 'Confirmed';
                    vehicle.Stock_Quantity__c -= 1;
                    ordersToUpdate.add(order);
                    vehiclesToUpdate.add(vehicle);
                }
            }
 
            if (!ordersToUpdate.isEmpty()) update ordersToUpdate;
            if (!vehiclesToUpdate.isEmpty()) update vehiclesToUpdate;
        }
    }
 
    global void finish(Database.BatchableContext bc) {
        System.debug('Vehicle order batch job completed.');
    }
}