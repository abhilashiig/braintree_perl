package Net::Braintree::CreditCard;
use Net::Braintree::CreditCard::CardType;
use Net::Braintree::CreditCard::Location;
use Net::Braintree::CreditCard::Prepaid;
use Net::Braintree::CreditCard::Debit;
use Net::Braintree::CreditCard::Payroll;
use Net::Braintree::CreditCard::Healthcare;
use Net::Braintree::CreditCard::DurbinRegulated;
use Net::Braintree::CreditCard::Commercial;
use Net::Braintree::CreditCard::CountryOfIssuance;
use Net::Braintree::CreditCard::IssuingBank;

use Moose;
extends 'Net::Braintree::PaymentMethod';

my $meta = __PACKAGE__->meta;

sub BUILD {
  my ($self, $attributes) = @_;
  $meta->add_attribute('billing_address', is => 'rw');
  $self->billing_address(Net::Braintree::Address->new($attributes->{billing_address})) if ref($attributes->{billing_address}) eq 'HASH';
  delete($attributes->{billing_address});
  $self->set_attributes_from_hash($self, $attributes);
}

sub create {
  my ($class, $params) = @_;
  $class->gateway->graphql->create_credit_card($params);
}

sub delete {
  my ($class, $token) = @_;
  $class->gateway->graphql->delete_payment_method($token);
}

sub update {
  my($class, $token, $params) = @_;
  $class->gateway->graphql->update_credit_card($token, $params);
}

sub find {
  my ($class, $token) = @_;
  $class->gateway->graphql->find_credit_card($token);
}

sub from_nonce {
  my ($class, $nonce) = @_;
  $class->gateway->graphql->credit_card_from_nonce($nonce);
}

sub gateway {
  Net::Braintree->configuration->gateway;
}

sub masked_number {
  my $self = shift;
  return $self->bin . "******" . $self->last_4;
}

sub expiration_date {
  my $self = shift;
  return $self->expiration_month . "/" . $self->expiration_year;
}

sub is_default {
  return shift->default;
}

sub is_venmo_sdk {
  my $self = shift;
  return $self->venmo_sdk;
}

1;
