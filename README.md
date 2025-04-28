# Unsupported warning

This library is deprecated and unsupported by Braintree. We recommend migrating to our [GraphQL API](https://graphql.braintreepayments.com/) instead.

Alternatively, you can find a community supported fork of this library at:

* [WebService::Braintree](https://metacpan.org/pod/WebService::Braintree)

# Braintree Perl Client Library with GraphQL Support

This library provides integration access to the Braintree Gateway using both the legacy REST API and the new GraphQL API.

## Important Notice

This is a community-maintained fork of the original Braintree Perl SDK with added GraphQL API support. This is NOT an official Braintree SDK and is not maintained by Braintree or PayPal.

## Features

- Full compatibility with existing code using the legacy REST API
- Support for the new Braintree GraphQL API
- Seamless switching between REST and GraphQL APIs
- Modern GraphQL queries and mutations for all major operations

## Dependencies

- Perl 5.8.1 or higher
- JSON module
- MIME::Base64 module

## Installation

```
perl Makefile.PL
make
make test
make install
```

## Using GraphQL API

By default, the SDK will use the GraphQL API for supported operations. If you want to disable GraphQL and use only the legacy REST API, you can do so by setting the `use_graphql` configuration option to `0`:

```perl
Net::Braintree->configuration->use_graphql(0);
```

You can also directly access the GraphQL client through the gateway:

```perl
my $result = Net::Braintree->configuration->gateway->graphql->create_transaction({
  amount => "10.00",
  payment_method_token => "payment_method_token",
  options => {
    submit_for_settlement => 1
  }
});
