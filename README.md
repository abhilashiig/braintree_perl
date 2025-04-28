# Unsupported warning

This library is deprecated and unsupported by Braintree. We recommend migrating to our [GraphQL API](https://graphql.braintreepayments.com/) instead.

Alternatively, you can find a community supported fork of this library at:

* [WebService::Braintree](https://metacpan.org/pod/WebService::Braintree)

# GraphQL-Only Braintree Perl Client Library

This library provides exclusive access to Braintree's modern GraphQL API for payment processing. The legacy REST APIs have been completely removed.

## ⚠️ IMPORTANT NOTICE ⚠️

This is a **COMMUNITY-MAINTAINED FORK** of the original Braintree Perl SDK. It is **NOT** an official Braintree SDK and is **NOT** maintained, supported, or endorsed by Braintree or PayPal.

## GraphQL-Only Implementation

Version 2.0.0 of this library has been completely rewritten to use **ONLY** the Braintree GraphQL API. All legacy REST API code has been removed. This provides several significant advantages:

- **Better Performance**: More efficient data retrieval with fewer API calls
- **Richer Responses**: Get exactly the data you need in a single request
- **Type Safety**: Strongly typed schema for better developer experience
- **Latest Features**: Access to the newest Braintree capabilities
- **Future-Proof**: Built on Braintree's strategic API direction

## Breaking Changes from Version 1.x

This is a **MAJOR** version update with breaking changes:

- All legacy REST API endpoints have been removed
- The configuration option `use_graphql` has been removed (GraphQL is now the only option)
- Gateway objects now directly expose GraphQL operations
- Response formats have been standardized to match GraphQL conventions

## Features

- ✅ Complete GraphQL API implementation
- ✅ Modern GraphQL queries and mutations
- ✅ Enhanced security with proper input validation
- ✅ Comprehensive error handling
- ✅ Detailed response parsing

## Dependencies

- Perl 5.8.1 or higher
- JSON module (2.90+)
- MIME::Base64 module
- HTTP::Request
- LWP::UserAgent with SSL support

## Installation

```
perl Makefile.PL
make
make test
make install
```

## Usage

### Basic Configuration

```perl
use Net::Braintree;

Net::Braintree->configuration->environment('sandbox');
Net::Braintree->configuration->merchant_id('your_merchant_id');
Net::Braintree->configuration->public_key('your_public_key');
Net::Braintree->configuration->private_key('your_private_key');

# Optional: Set GraphQL API version (defaults to 2025-04-28)
Net::Braintree->configuration->graphql_version('2025-04-28');

# Optional: Set request timeout in seconds (defaults to 60)
Net::Braintree->configuration->graphql_timeout(90);
```

### Transaction Operations

```perl
# Create a transaction
my $result = Net::Braintree->configuration->gateway->graphql->create_transaction({
  amount => "10.00",
  payment_method_token => "payment_method_token",
  options => {
    submit_for_settlement => 1
  }
});

# Find a transaction
my $transaction = Net::Braintree->configuration->gateway->graphql->find_transaction('transaction_id');

# Void a transaction
my $void_result = Net::Braintree->configuration->gateway->graphql->void_transaction('transaction_id');

# Refund a transaction
my $refund_result = Net::Braintree->configuration->gateway->graphql->refund_transaction('transaction_id', { amount => '5.00' });
```

### Customer Operations

```perl
# Create a customer
my $customer_result = Net::Braintree->configuration->gateway->graphql->create_customer({
  first_name => "John",
  last_name => "Doe",
  email => "john.doe@example.com"
});

# Find a customer
my $customer = Net::Braintree->configuration->gateway->graphql->find_customer('customer_id');

# Update a customer
my $update_result = Net::Braintree->configuration->gateway->graphql->update_customer('customer_id', {
  email => "new.email@example.com"
});

# Delete a customer
my $delete_result = Net::Braintree->configuration->gateway->graphql->delete_customer('customer_id');
```

### Payment Method Operations

```perl
# Create a payment method
my $payment_method_result = Net::Braintree->configuration->gateway->graphql->create_payment_method({
  payment_method_nonce => "nonce_from_client",
  customer_id => "customer_id"
});

# Find a payment method
my $payment_method = Net::Braintree->configuration->gateway->graphql->find_payment_method('payment_method_token');

# Update a payment method
my $update_result = Net::Braintree->configuration->gateway->graphql->update_payment_method('payment_method_token', {
  cardholder_name => "New Name",
  expiration_month => "12",
  expiration_year => "2025"
});

# Delete a payment method
my $delete_result = Net::Braintree->configuration->gateway->graphql->delete_payment_method('payment_method_token');
```

### Client Token Generation

```perl
# Generate a client token
my $token_result = Net::Braintree->configuration->gateway->graphql->generate_client_token({
  customer_id => "customer_id"  # Optional
});

my $client_token = $token_result->{client_token};
