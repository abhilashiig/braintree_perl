package Net::Braintree::Configuration;

use Net::Braintree::Gateway;
use Moose;

has merchant_id => (is => 'rw');
has partner_id => (is => 'rw');
has public_key  => (is => 'rw');
has private_key => (is => 'rw');
has gateway => (is  => 'ro', lazy => 1, default => sub { Net::Braintree::Gateway->new({config => shift})});
has graphql_version => (is => 'rw', default => '2025-04-28');
has graphql_timeout => (is => 'rw', default => 60);

has environment => (
  is => 'rw',
  trigger => sub {
    my ($self, $new_value, $old_value) = @_;
    if ($new_value !~ /integration|development|sandbox|production|qa/) {
      warn "Assigned invalid value to Net::Braintree::Configuration::environment";
    }
    if ($new_value eq "integration") {
      $self->public_key("integration_public_key");
      $self->private_key("integration_private_key");
      $self->merchant_id("integration_merchant_id");
    }
  }
);

# GraphQL API methods only - legacy REST API methods removed

sub graphql_server {
  my $self = shift;
  return "payments.sandbox.braintree-api.com" if $self->environment eq 'sandbox';
  return "payments.braintree-api.com" if $self->environment eq 'production';
  return "payments.sandbox.braintree-api.com" if $self->environment eq 'development';
  return "payments.sandbox.braintree-api.com" if $self->environment eq 'integration';
  return "payments.qa.braintree-api.com" if $self->environment eq 'qa';
  # Default to sandbox for any other environment
  return "payments.sandbox.braintree-api.com";
}

sub graphql_server {
  my $self = shift;
  return "payments.sandbox.braintree-api.com" if $self->environment eq 'sandbox';
  return "payments.braintree-api.com" if $self->environment eq 'production';
  # For development/testing environments, fallback to sandbox
  return "payments.sandbox.braintree-api.com";
}

# GraphQL doesn't use the auth_url - method kept for backward compatibility
sub auth_url {
  my $self = shift;
  return "https://auth.sandbox.venmo.com" if $self->environment eq 'sandbox';
  return "https://auth.venmo.com" if $self->environment eq 'production';
  return "https://auth.sandbox.venmo.com";
}

# GraphQL always uses HTTPS
sub ssl_enabled {
  return 1;
}

sub protocol {
  return 'https';
}

sub graphql_endpoint {
  my $self = shift;
  return $self->protocol . "://" . $self->graphql_server . '/graphql';
}

1;
