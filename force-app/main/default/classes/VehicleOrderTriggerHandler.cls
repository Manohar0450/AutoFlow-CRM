public class VehicleOrderTriggerHandler {

    // Status constant (better to use Custom Metadata or Custom Settings in real projects)
    private static final String STATUS_CONFIRMED = 'Confirmed';

    public static void handleTrigger(
        List<Order__c> newOrders,
        Map<Id, Order__c> oldOrders,
        Boolean isBefore,
        Boolean isAfter,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (isBefore && (isInsert || isUpdate)) {
            preventOrderIfOutOfStock(newOrders);
        }

        if (isAfter && (isInsert || isUpdate)) {
            updateStockOnOrderPlacement(newOrders, oldOrders);
        }
    }

    // ❌ Prevent placing an order if stock is zero or negative
    private static void preventOrderIfOutOfStock(List<Order__c> orders) {
        Set<Id> vehicleIds = new Set<Id>();
        for (Order__c order : orders) {
            if (Order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
            }
        }

        if (!vehicleIds.isEmpty()) {
            Map<Id, Vechcle__c> vehicleStockMap = new Map<Id, Vechcle__c>(
                [SELECT Id, Stock_Quantity__c FROM Vechcle__c WHERE Id IN :vehicleIds]
            );

            for (Order__c order : orders) {
                Vechcle__c vehicle = vehicleStockMap.get(order.Vehicle__c);
                if (vehicle != null && vehicle.Stock_Quantity__c <= 0) {
                    order.addError('This vehicle is out of stock. Order cannot be placed.');
                }
            }
        }
    }

    // ✅ Decrease stock when an order is confirmed
    private static void updateStockOnOrderPlacement(List<Order__c> newOrders, Map<Id, Order__c> oldOrders) {
        Map<Id, Integer> vehicleOrderCounts = new Map<Id, Integer>();

        // Collect vehicle order counts (only for new confirmed orders)
        for (Order__c order : newOrders) {
            Order__c oldOrder = (oldOrders != null && oldOrders.containsKey(order.Id)) ? oldOrders.get(order.Id) : null;

            Boolean isNewlyConfirmed = order.Status__c == STATUS_CONFIRMED &&
                                       (oldOrder == null || oldOrder.Status__c != STATUS_CONFIRMED);

            if (order.Vehicle__c != null && isNewlyConfirmed) {
                Integer currentCount = vehicleOrderCounts.containsKey(order.Vehicle__c) ? vehicleOrderCounts.get(order.Vehicle__c) : 0;
                vehicleOrderCounts.put(order.Vehicle__c, currentCount + 1);
            }
        }

        if (!vehicleOrderCounts.isEmpty()) {
            // Lock rows to prevent race conditions
            Map<Id, Vechcle__c> vehicleStockMap = new Map<Id, Vechcle__c>(
                [SELECT Id, Stock_Quantity__c FROM Vechcle__c WHERE Id IN :vehicleOrderCounts.keySet() FOR UPDATE]
            );

            List<Vechcle__c> vehiclesToUpdate = new List<Vechcle__c>();

            for (Id vehicleId : vehicleOrderCounts.keySet()) {
                Vechcle__c vehicle = vehicleStockMap.get(vehicleId);
                Integer orderCount = vehicleOrderCounts.get(vehicleId);

                if (vehicle != null && vehicle.Stock_Quantity__c >= orderCount) {
                    vehicle.Stock_Quantity__c -= orderCount;
                    vehiclesToUpdate.add(vehicle);
                } else if (vehicle != null) {           
                    vehicle.Stock_Quantity__c = 0;
                    vehiclesToUpdate.add(vehicle);
                }
            }

            if (!vehiclesToUpdate.isEmpty()) {
                update vehiclesToUpdate;
            }
        }
    }
}