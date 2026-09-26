import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/features/catalog/data/models/catalog_service.dart';
import 'package:ezyventas_app/features/catalog/data/models/category.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/customers/data/models/customer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Producto con la forma **real** de `GET /catalog/products` (verificada contra
/// `https://ezyventas2.test/api/v1`): `selling_price` es texto y
/// `price` / `original_price` son números.
Map<String, dynamic> productFixture() => <String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'description': 'Filtro para motor 1.6',
  'category': 'Refacciones',
  'image': 'https://ezyventas2.test/storage/filtro.jpg',
  'general_images': <String>['https://ezyventas2.test/storage/filtro-2.jpg'],
  'selling_price': '150.00',
  'price': 135.0,
  'original_price': 150.0,
  'price_tiers': <Map<String, dynamic>>[
    <String, dynamic>{'min_quantity': 6, 'price': 130},
    <String, dynamic>{'min_quantity': 12, 'price': 120},
  ],
  'stock': 24.0,
  'reserved_stock': 0.0,
  'is_bulk': false,
  'measure_unit': 'pz',
  'show_in_pos': true,
  'promotions': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'Ofertas de septiembre',
      'type': 'ITEM_DISCOUNT',
      'description': '10 % en filtros',
    },
  ],
  'variants': <String, dynamic>{
    'Talla': <Map<String, dynamic>>[
      <String, dynamic>{'value': 'M', 'stock': 3},
    ],
  },
  'variant_combinations': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 88,
      'attributes': <String, dynamic>{'Talla': 'M', 'Color': 'Azul'},
      'price_modifier': 15.0,
      'price': 165.0,
      'sku_suffix': 'M-AZ',
      'stock': 3,
      'reserved_stock': 0.0,
      'image_url': null,
    },
  ],
  'components': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 3,
      'component_id': 12,
      'component_type': 'product',
      'name': 'Goma',
      'quantity': 1,
    },
  ],
};

void main() {
  group('Product', () {
    test('normaliza los tipos mezclados del contrato', () {
      final product = Product.fromJson(productFixture());

      expect(product.sellingPrice, 150.0);
      expect(product.price, 135.0);
      expect(product.originalPrice, 150.0);
      expect(product.stock, 24.0);
      expect(product.reservedStock, 0.0);
      expect(product.measureUnit, 'pz');
      expect(product.showInPos, isTrue);
      expect(product.isBulk, isFalse);
      expect(product.hasPromotion, isTrue);
      expect(product.displayImage, contains('filtro.jpg'));
      // La galería del detalle se arma con la portada y `general_images`.
      expect(product.galleryImages, <String>[
        'https://ezyventas2.test/storage/filtro.jpg',
        'https://ezyventas2.test/storage/filtro-2.jpg',
      ]);
      expect(product.cardImage, 'https://ezyventas2.test/storage/filtro.jpg');
      expect(product.components.single.name, 'Goma');
    });

    test('lee precios por volumen y aplica el tier correcto', () {
      final product = Product.fromJson(productFixture());

      expect(product.hasPriceTiers, isTrue);
      expect(product.priceForQuantity(5), 135.0);
      expect(product.priceForQuantity(6), 130.0);
      expect(product.priceForQuantity(20), 120.0);
    });

    test('lee variantes y combinaciones vendibles', () {
      final product = Product.fromJson(productFixture());

      expect(product.hasVariants, isTrue);
      expect(product.variants['Talla']!.single.value, 'M');
      expect(product.variants['Talla']!.single.stock, 3.0);

      final combination = product.variantCombinations.single;
      expect(combination.id, 88);
      expect(combination.price, 165.0);
      expect(combination.priceModifier, 15.0);
      expect(combination.label, 'Talla M · Color Azul');
      expect(combination.isOutOfStock, isFalse);
      expect(combination.imageUrl, isNull);
    });

    test('producto sin variantes ni promoción queda simple', () {
      final product = Product.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Producto básico',
        'selling_price': '3900.00',
        'price': 3900,
        'original_price': 3900,
        'stock': 0,
        'image': null,
        'general_images': <String>[],
        'variants': <String, dynamic>{},
      });

      expect(product.sellingPrice, 3900.0);
      expect(product.hasVariants, isFalse);
      expect(product.hasPromotion, isFalse);
      expect(product.isOutOfStock, isTrue);
      expect(product.displayImage, isNull);
      expect(product.priceForQuantity(10), 3900.0);
    });

    test('la portada repetida en general_images no duplica la galería', () {
      // El servidor manda la portada también dentro de `general_images`: el
      // detalle debe dar dos páginas, no tres.
      final product = Product.fromJson(<String, dynamic>{
        'id': 2,
        'name': 'Funda',
        'selling_price': '100.00',
        'price': 100,
        'original_price': 100,
        'stock': 3,
        'image': 'https://ezyventas2.test/storage/funda.jpg',
        'general_images': <String>[
          'https://ezyventas2.test/storage/funda.jpg',
          'https://ezyventas2.test/storage/funda-2.jpg',
        ],
      });

      expect(product.galleryImages, <String>[
        'https://ezyventas2.test/storage/funda.jpg',
        'https://ezyventas2.test/storage/funda-2.jpg',
      ]);
    });

    test('el marcador del servidor (placehold.co) no cuenta como imagen', () {
      // `ProductCatalogService::payload` pone esa URL cuando el producto no
      // tiene fotos propias: la app dibuja su propio marcador en lugar del
      // cuadro gris del servicio.
      final product = Product.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Iphone 20',
        'selling_price': '12000.00',
        'price': 12000,
        'original_price': 12000,
        'stock': 4,
        'image': 'https://placehold.co/400x400/EBF8FF/3182CE?text=Iphone%2020',
        'general_images': <String>[],
      });

      expect(product.displayImage, isNull);
      expect(product.galleryImages, isEmpty);
      expect(product.cardImage, isNull);
    });

    test('producto de solo variantes usa la foto de su primera variante', () {
      // Caso real del POS: las fotos viven en
      // `variant_combinations[].image_url` y el producto no tiene fotos propias,
      // así que la tarjeta y el detalle caen a la de la variante (como la web).
      final product = Product.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Playera',
        'selling_price': '200.00',
        'price': 200,
        'original_price': 200,
        'stock': 0,
        'image': 'https://placehold.co/400x400/EBF8FF/3182CE?text=Playera',
        'general_images': <String>[],
        'variant_combinations': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 30,
            'attributes': <String, dynamic>{'Talla': 'M'},
            'price': 200.0,
            'stock': 2.0,
            'image_url': 'https://ezyventas2.test/storage/playera-m.jpg',
          },
          <String, dynamic>{
            'id': 31,
            'attributes': <String, dynamic>{'Talla': 'G'},
            'price': 200.0,
            'stock': 1.0,
            'image_url': null,
          },
        ],
      });

      expect(
        product.variantCombinations.first.imageUrl,
        'https://ezyventas2.test/storage/playera-m.jpg',
      );
      expect(
        product.cardImage,
        'https://ezyventas2.test/storage/playera-m.jpg',
      );
      // El producto no tiene fotos propias: la galería se queda con la de la
      // variante que el detalle elija.
      expect(product.galleryImages, isEmpty);
    });
  });

  group('Paginated', () {
    test('lee el sobre de paginación del backend', () {
      final page = Paginated<Product>.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[productFixture()],
        'current_page': 1,
        'last_page': 3,
        'per_page': 20,
        'total': 52,
      }, Product.fromJson);

      expect(page.items, hasLength(1));
      expect(page.total, 52);
      expect(page.lastPage, 3);
      expect(page.hasMore, isTrue);
    });

    test('una última página no tiene más', () {
      final page = Paginated<Product>.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[],
        'current_page': 3,
        'last_page': 3,
        'per_page': 20,
        'total': 52,
      }, Product.fromJson);

      expect(page.hasMore, isFalse);
      expect(page.isEmpty, isTrue);
    });
  });

  group('Category y CatalogService', () {
    test('lee las categorías de la suscripción', () {
      final category = Category.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'Refacciones',
        'type': 'product',
      });

      expect(category.id, 3);
      expect(category.label, 'Refacciones');
    });

    test('lee el servicio con variantes (precios en texto)', () {
      final service = CatalogService.fromJson(<String, dynamic>{
        'id': 12,
        'name': 'Cambio de pantalla',
        'description': 'Incluye instalación',
        'category': 'Reparaciones',
        'base_price': '850.00',
        'duration_estimate': '2 horas',
        'show_online': false,
        'variants': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 31,
            'name': 'Original',
            'price': '1450.00',
            'duration_estimate': null,
          },
          <String, dynamic>{
            'id': 32,
            'name': 'Compatible',
            'price': '850.00',
            'duration_estimate': null,
          },
        ],
      });

      expect(service.basePrice, 850.0);
      expect(service.hasVariants, isTrue);
      expect(service.variants, hasLength(2));
      expect(service.lowestPrice, 850.0);
      expect(service.durationEstimate, '2 horas');
    });
  });

  group('Customer', () {
    test('lee saldo y crédito mezclando texto y número', () {
      final customer = Customer.fromJson(<String, dynamic>{
        'id': 8,
        'name': 'Ana Ramírez',
        'company_name': null,
        'email': 'ana@correo.com',
        'phone': '4771112233',
        'balance': '-350.00',
        'credit_limit': '2000.00',
        'available_credit': 1650.0,
      });

      expect(customer.balance, -350.0);
      expect(customer.creditLimit, 2000.0);
      expect(customer.availableCredit, 1650.0);
      expect(customer.hasDebt, isTrue);
      expect(customer.hasBalanceInFavor, isFalse);
      expect(customer.hasCredit, isTrue);
      expect(customer.displayName, 'Ana Ramírez');
    });

    test('cliente con saldo a favor usa la razón social', () {
      final customer = Customer.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Juan',
        'company_name': 'Refacciones Juan SA',
        'balance': '500.00',
        'credit_limit': '0.00',
      });

      expect(customer.hasBalanceInFavor, isTrue);
      expect(customer.hasCredit, isFalse);
      expect(customer.displayName, 'Refacciones Juan SA');
    });
  });

  group('CustomerDetail', () {
    test('lee apartados, dirección y movimientos de saldo', () {
      final detail = CustomerDetail.fromJson(<String, dynamic>{
        'id': 8,
        'name': 'Ana Ramírez',
        'balance': '-600.00',
        'credit_limit': '2000.00',
        'available_credit': 1400.0,
        'address': <String, dynamic>{
          'street': 'Av. Hidalgo 120',
          'city': 'León',
        },
        'tax_id': 'XAXX010101000',
        'tax_regime': '601',
        'layaway_transactions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 91,
            'folio': 'V-5001',
            'created_at': '2026-09-10T18:00:00.000000Z',
            'expires_at': '2026-10-10',
            'total': '900.00',
            'total_paid': '300.00',
            'pending_amount': '600.00',
            'items_count': 2,
          },
        ],
        'balance_movements': <Map<String, dynamic>>[
          <String, dynamic>{
            'date': '2026-09-10T18:05:00.000000Z',
            'type': 'apartado_deuda',
            'description': 'Abono...',
            'amount': '-600.00',
            'resulting_balance': '-600.00',
            'transaction_id': 91,
          },
        ],
      });

      expect(detail.customer.balance, -600.0);
      expect(detail.addressLine, 'Av. Hidalgo 120, León');
      expect(detail.taxId, 'XAXX010101000');
      expect(detail.layaways.single.folio, 'V-5001');
      expect(detail.layaways.single.pendingAmount, 600.0);
      expect(detail.layaways.single.itemsCount, 2);
      expect(detail.layaways.single.createdAt, isNotNull);
      expect(detail.balanceMovements.single.isCharge, isTrue);
      expect(detail.balanceMovements.single.transactionId, 91);
    });
  });
}
