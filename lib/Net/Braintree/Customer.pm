package Net::Braintree::Customer;
use Moose;
extends 'Net::Braintree::ResultObject';

my $meta = __PACKAGE__->meta;

sub BUILD {
  my ($self, $attributes) = @_;
  my $sub_objects = {
    credit_cards => "Net::Braintree::CreditCard",
    addresses => "Net::Braintree::Address",
    paypal_accounts => "Net::Braintree::PayPalAccount"
  };

  $self->setup_sub_objects($self, $attributes, $sub_objects);
  $self->set_attributes_from_hash($self, $attributes);
}

sub payment_methods {
  my $self = shift;
  my @pmt_methods;
  if (defined($self->credit_cards)) {
    foreach my $credit_card (@{$self->credit_cards}) {
      push @pmt_methods, $credit_card;
    }
  }

  if (defined($self->paypal_accounts)) {
    foreach my $paypal_account (@{$self->paypal_accounts}) {
      push @pmt_methods, $paypal_account;
    }
  }

  return \@pmt_methods;
}

sub create {
  my ($class, $params) = @_;
  $class->gateway->graphql->create_customer($params);
}

sub find {
  my($class, $id) = @_;
  $class->gateway->graphql->find_customer($id);
}

sub delete {
  my ($class, $id) = @_;
  $class->gateway->graphql->delete_customer($id);
}

sub update {
  my ($class, $id, $params) = @_;
  $class->gateway->graphql->update_customer($id, $params);
}

sub search {
  my ($class, $block) = @_;
  # GraphQL doesn't support the same search mechanism
  # Use the search criteria to construct a GraphQL query
  my $search_params = $block->(Net::Braintree::CustomerSearch->new)->to_hash;
  $class->gateway->graphql->search_customers($search_params);
}

sub all {
  my ($class) = @_;
  $class->gateway->graphql->get_all_customers();
}

sub gateway {
  return Net::Braintree->configuration->gateway;
}

1;
