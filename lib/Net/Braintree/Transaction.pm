package Net::Braintree::Transaction;
use Net::Braintree::Transaction::CreatedUsing;
use Net::Braintree::Transaction::EscrowStatus;
use Net::Braintree::Transaction::Source;
use Net::Braintree::Transaction::Status;
use Net::Braintree::Transaction::Type;

use Moose;
extends "Net::Braintree::ResultObject";
my $meta = __PACKAGE__->meta;

sub BUILD {
  my ($self, $attributes) = @_;
  my $sub_objects = { 'disputes' => 'Net::Braintree::Dispute'};
  $meta->add_attribute('subscription', is => 'rw');
  $self->subscription(Net::Braintree::Subscription->new($attributes->{subscription})) if ref($attributes->{subscription}) eq 'HASH';
  delete($attributes->{subscription});
  $meta->add_attribute('disbursement_details', is => 'rw');
  $self->disbursement_details(Net::Braintree::DisbursementDetails->new($attributes->{disbursement_details})) if ref($attributes->{disbursement_details}) eq 'HASH';
  delete($attributes->{disbursement_details});

  $meta->add_attribute('paypal_details', is => 'rw');
  $self->paypal_details(Net::Braintree::PayPalDetails->new($attributes->{paypal})) if ref($attributes->{paypal}) eq 'HASH';
  delete($attributes->{paypal});

  $self->setup_sub_objects($self, $attributes, $sub_objects);
  $self->set_attributes_from_hash($self, $attributes);
}

sub sale {
  my ($class, $params) = @_;
  $class->create($params, 'sale');
}

sub credit {
  my ($class, $params) = @_;
  $class->create($params, 'credit');
}

sub submit_for_settlement {
  my ($class, $id, $amount) = @_;
  my $params = {};
  $params->{'amount'} = $amount if $amount;
  $class->gateway->graphql->submit_for_settlement($id, $params);
}

sub void {
  my ($class, $id) = @_;
  $class->gateway->graphql->void_transaction($id);
}

sub refund {
  my ($class, $id, $amount) = @_;
  my $params = {};
  $params->{'amount'} = $amount if $amount;
  $class->gateway->graphql->refund_transaction($id, $params);
}

sub create {
  my ($class, $params, $type) = @_;
  $params->{'type'} = $type;
  $class->gateway->graphql->create_transaction($params);
}

sub find {
  my ($class, $id) = @_;
  $class->gateway->graphql->find_transaction($id);
}

sub search {
  my ($class, $block) = @_;
  # GraphQL doesn't support the same search mechanism
  # Use the search criteria to construct a GraphQL query
  my $search_params = $block->(Net::Braintree::TransactionSearch->new)->to_hash;
  $class->gateway->graphql->search_transactions($search_params);
}

sub hold_in_escrow {
  my ($class, $id) = @_;
  $class->gateway->graphql->hold_transaction_in_escrow($id);
}

sub release_from_escrow {
  my ($class, $id) = @_;
  $class->gateway->graphql->release_transaction_from_escrow($id);
}

sub cancel_release {
  my ($class, $id) = @_;
  $class->gateway->graphql->cancel_transaction_release($id);
}

sub all {
  my $class = shift;
  $class->gateway->graphql->get_all_transactions();
}

sub clone_transaction {
  my ($class, $id, $params) = @_;
  $class->gateway->graphql->clone_transaction($id, $params);
}

sub gateway {
  Net::Braintree->configuration->gateway;
}

sub is_disbursed {
  my $self = shift;
  $self->disbursement_details->is_valid();
};

1;
