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
    
    # Validate credentials before proceeding
    unless ($self->config->public_key && $self->config->private_key) {
        confess "SecurityError: Missing authentication credentials. Both public_key and private_key must be provided.";
    }
    
    # Validate payload
    unless ($payload && $payload->{query}) {
        confess "InvalidRequestError: Missing required query in GraphQL request";
    }
    
    my $request = HTTP::Request->new('POST' => $self->graphql_endpoint);
    
    # Set authorization header with proper encoding
    my $auth_string = $self->config->public_key . ':' . $self->config->private_key;
    my $encoded_auth = encode_base64($auth_string, '');
    $request->header('Authorization' => "Basic $encoded_auth");
    
    # Set required headers
    $request->header('Braintree-Version' => $self->config->graphql_version || '2025-04-28');
    $request->header('Content-Type' => 'application/json');
    $request->header('User-Agent' => 'Braintree Perl GraphQL Client ' . Net::Braintree->VERSION);
    
    # Set request body with safe JSON encoding
    my $json_payload;
    eval {
        $json_payload = encode_json($payload);
    };
    if ($@) {
        confess "SerializationError: Failed to encode request payload to JSON: $@";
    }
    $request->content($json_payload);
    
    # Configure UserAgent with proper security settings
    my $agent = LWP::UserAgent->new(
        timeout => 60,  # Set reasonable timeout
        ssl_opts => {
            verify_hostname => 1,  # Enforce SSL certificate validation
            SSL_verify_mode => 0x01  # SSL_VERIFY_PEER
        }
    );
    
    # Execute request with error handling
    my $response;
    eval {
        $response = $agent->request($request);
    };
    if ($@) {
        confess "NetworkError: Failed to execute HTTP request: $@";
    }
    
    unless ($response) {
        confess "NetworkError: No response received from server";
    }
    
    # Check response code
    $self->check_response_code($response->code);
    
    # Parse response with robust error handling
    my $content = $response->content;
    unless ($content) {
        confess "EmptyResponseError: Received empty response from server";
    }
    
    my $result;
    eval {
        $result = decode_json($content);
    };
    if ($@) {
        confess "DeserializationError: Failed to parse JSON response: $@\nResponse content: $content";
    }
    
    # Check for GraphQL errors with detailed reporting
    if (exists $result->{errors} && ref($result->{errors}) eq 'ARRAY' && @{$result->{errors}}) {
        my $error_count = scalar @{$result->{errors}};
        my $primary_error = $result->{errors}->[0];
        my $error_message = $primary_error->{message} || 'Unknown GraphQL error';
        my $error_code = $primary_error->{extensions}->{errorClass} || 'GraphQLError';
        my $error_detail = "$error_code: $error_message";
        
        if ($error_count > 1) {
            $error_detail .= " (plus " . ($error_count - 1) . " additional errors)";
        }
        
        confess $error_detail;
    }
    
    return $result;
}

# Check HTTP response code with detailed error messages
sub check_response_code {
    my ($self, $code) = @_;
    
    my %error_types = (
        '400' => 'BadRequestError: The request was malformed or contained invalid parameters',
        '401' => 'AuthenticationError: Authentication failed, check your API credentials',
        '402' => 'PaymentRequiredError: The API request requires payment to proceed',
        '403' => 'AuthorizationError: The credentials provided do not have permission to access this resource',
        '404' => 'NotFoundError: The requested resource was not found',
        '422' => 'ValidationError: The request was well-formed but contains semantic errors',
        '429' => 'RateLimitError: Too many requests, please implement exponential backoff',
        '500' => 'ServerError: An error occurred on the Braintree server',
        '502' => 'BadGatewayError: Invalid response from the upstream server',
        '503' => 'DownForMaintenanceError: The Braintree API is currently unavailable',
        '504' => 'GatewayTimeoutError: The gateway timed out trying to connect to Braintree'
    );
    
    if (exists $error_types{$code}) {
        confess $error_types{$code};
    }
    
    # For any other non-2xx status code not explicitly handled
    if ($code !~ /^2\d\d$/) {
        confess "UnexpectedError: Received unexpected HTTP status code $code";
    }
}

1;
