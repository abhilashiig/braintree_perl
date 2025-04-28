package Net::Braintree::GraphQL;

use Moose;
use HTTP::Request;
use LWP::UserAgent;
use JSON;
use MIME::Base64;
use Carp qw(confess);

has 'config' => (is => 'ro', default => sub { Net::Braintree->configuration });

# GraphQL endpoints
sub graphql_endpoint {
    my $self = shift;
    my $environment = $self->config->environment;
    
    if ($environment eq 'sandbox') {
        return 'https://payments.sandbox.braintree-api.com/graphql';
    } elsif ($environment eq 'production') {
        return 'https://payments.braintree-api.com/graphql';
    } elsif ($environment eq 'development' || $environment eq 'integration') {
        # For development/testing environments, fallback to sandbox
        return 'https://payments.sandbox.braintree-api.com/graphql';
    } else {
        confess "Unknown environment: $environment";
    }
}

# Execute a GraphQL query
sub query {
    my ($self, $query_string, $variables) = @_;
    
    my $payload = {
        query => $query_string,
    };
    
    if ($variables) {
        $payload->{variables} = $variables;
    }
    
    return $self->execute_request($payload);
}

# Execute a GraphQL mutation
sub mutate {
    my ($self, $mutation_string, $variables) = @_;
    
    my $payload = {
        query => $mutation_string,
    };
    
    if ($variables) {
        $payload->{variables} = $variables;
    }
    
    return $self->execute_request($payload);
}

# Execute the GraphQL request
sub execute_request {
    my ($self, $payload) = @_;
    
    my $request = HTTP::Request->new('POST' => $self->graphql_endpoint);
    
    # Set authorization header
    my $auth_string = $self->config->public_key . ':' . $self->config->private_key;
    my $encoded_auth = encode_base64($auth_string, '');
    $request->header('Authorization' => "Basic $encoded_auth");
    
    # Set required headers
    $request->header('Braintree-Version' => '2023-01-01');
    $request->header('Content-Type' => 'application/json');
    $request->header('User-Agent' => 'Braintree Perl GraphQL Client ' . Net::Braintree->VERSION);
    
    # Set request body
    $request->content(encode_json($payload));
    
    # Execute request
    my $agent = LWP::UserAgent->new;
    my $response = $agent->request($request);
    
    # Check response code
    $self->check_response_code($response->code);
    
    # Parse response
    my $content = $response->content;
    my $result = eval { decode_json($content) };
    
    if ($@) {
        confess "Failed to parse JSON response: $@";
    }
    
    # Check for GraphQL errors
    if (exists $result->{errors} && @{$result->{errors}}) {
        my $error_message = $result->{errors}->[0]->{message} || 'Unknown GraphQL error';
        confess "GraphQLError: $error_message";
    }
    
    return $result;
}

# Check HTTP response code
sub check_response_code {
    my ($self, $code) = @_;
    confess "NotFoundError"       if $code eq '404';
    confess "AuthenticationError" if $code eq '401';
    confess "AuthorizationError"  if $code eq '403';
    confess "ServerError"         if $code eq '500';
    confess "DownForMaintenance"  if $code eq '503';
}

1;
