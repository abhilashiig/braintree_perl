package Net::Braintree::PaymentMethod;
use Moose;
extends 'Net::Braintree::ResultObject';

has token => ( is => 'rw' );

sub create {
  my ($class, $params) = @_;
  $class->gateway->graphql->create_payment_method($params);
}

sub update {
  my ($class, $token, $params) = @_;
  $class->gateway->graphql->update_payment_method($token, $params);
}

sub delete {
  my ($class, $token) = @_;
  $class->gateway->graphql->delete_payment_method($token);
}

sub find {
  my ($class, $token) = @_;
  $class->gateway->graphql->find_payment_method($token);
}

sub gateway {
  return Net::Braintree->configuration->gateway;
}

1;
