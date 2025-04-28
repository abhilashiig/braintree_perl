package Net::Braintree::Gateway;

# Only GraphQL gateway is used in this version
use Net::Braintree::GraphQLGateway;

use Moose;

has 'config' => (is => 'ro');

# Only GraphQL gateway is available in this version
has 'graphql' => (is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  Net::Braintree::GraphQLGateway->new(gateway => $self, config => $self->config);
});

# Convenience methods that map to GraphQL operations
has 'transaction' => (is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->graphql;
});

has 'customer' => (is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->graphql;
});

has 'payment_method' => (is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->graphql;
});

has 'client_token' => (is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->graphql;
});

# Legacy HTTP client removed - only GraphQL is supported

1;
