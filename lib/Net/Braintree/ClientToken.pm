package Net::Braintree::ClientToken;

use constant DEFAULT_VERSION => "2";

sub generate {
  my ($class, $params) = @_;
  if (!exists $params->{version}) {
    $params->{version} = DEFAULT_VERSION;
  }

  $class->gateway->graphql->generate_client_token($params);
}

sub gateway {
  Net::Braintree->configuration->gateway;
}

1;
