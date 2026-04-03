class Endpoint {
  // AUTH
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const refresh = '/auth/refresh';

  // MASTER DATA
  static const cmt = '/cmt';
  static const color = '/color';
  static const factory = '/factory';
  static const inventory = '/inventory';
  static const marketplace = '/marketplace';
  static const onlineStore = '/onlinestore';
  static const productModel = '/model';
  static const modelColor = '/model_color';
  static const modelSize = '/model_size';
  static const product = '/product';
  static const rack = '/rack';
  static const size = '/size';
  static const warehouse = '/warehouse';
  static const user = '/user';
  static const role = '/role';

  // TRANSACTION
  static const request = '/request';
  static const inbound = '/inbound';
  static const order = '/order';

  // OUTBOUND
  static const outboundValidateAwb = '/outbound/validate-awb';
  static const outboundOrderItems = '/outbound/order-items';
  static const outboundValidateProductBarcode =
      '/outbound/validate-product-barcode';
  static const outboundSubmitPreparation = '/outbound/submit-preparation';
  static const outboundAssignOrder = '/outbound/assign-order';
  static const outboundUnassignOrder = '/outbound/unassign-order';
  static const outboundAssignedOrders = '/outbound/assigned-orders';

  // CHECKER
  static const checkerAssignedOrders = '/checker/assigned-orders';
  static const checkerSearchBySerial = '/checker/search-by-serial';
  static const checkerOrderItems = '/checker/order-items';
  static const checkerValidateProductBarcode =
      '/checker/validate-product-barcode';
  static const checkerApproveOrder = '/checker/approve-order';
}
