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
}
