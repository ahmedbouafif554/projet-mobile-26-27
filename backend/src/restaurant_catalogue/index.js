'use strict';

const restaurantRoutes = require('./routes/restaurant.routes');
const productRoutes = require('./routes/product.routes');
const categoryRoutes = require('./routes/category.routes');

const restaurantService = require('./services/restaurant.service');
const productService = require('./services/product.service');
const categoryService = require('./services/category.service');
const { init } = require('./catalogue.schema');

module.exports = {
  init,
  restaurantRoutes,
  productRoutes,
  categoryRoutes,
  restaurantService,
  productService,
  categoryService,
};
