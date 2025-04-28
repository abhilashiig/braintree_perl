package Net::Braintree::GraphQLGateway;

use Moose;
use Net::Braintree::GraphQL;
use Net::Braintree::Result;
use JSON;
use Carp qw(confess);

has 'config' => (is => 'ro', default => sub { Net::Braintree->configuration });
has 'graphql' => (is => 'ro', lazy => 1, default => sub { Net::Braintree::GraphQL->new(config => shift->config) });

# Convert REST-style response to GraphQL-style response
sub _convert_response {
    my ($self, $graphql_response, $entity_type) = @_;
    
    # If no entity type is specified, just return the data
    return $graphql_response->{data} unless $entity_type;
    
    # Create a response structure compatible with the existing SDK
    my $response = {};
    
    # Extract the relevant data from the GraphQL response
    if ($graphql_response->{data}) {
        my $data = $graphql_response->{data};
        
        # Find the first key in the data object (should be the operation name)
        my ($operation) = keys %$data;
        
        if ($operation && $data->{$operation}) {
            # For most entity types, the data will be directly under the operation
            if ($entity_type eq 'transaction' && $data->{$operation}->{transaction}) {
                $response->{transaction} = $data->{$operation}->{transaction};
            }
            elsif ($entity_type eq 'customer' && $data->{$operation}->{customer}) {
                $response->{customer} = $data->{$operation}->{customer};
            }
            elsif ($entity_type eq 'credit_card' && $data->{$operation}->{creditCard}) {
                $response->{credit_card} = $data->{$operation}->{creditCard};
            }
            elsif ($entity_type eq 'payment_method' && $data->{$operation}->{paymentMethod}) {
                $response->{payment_method} = $data->{$operation}->{paymentMethod};
            }
            else {
                # Default case - just use the operation result
                $response->{$entity_type} = $data->{$operation};
            }
        }
    }
    
    return $response;
}

# Create a result object from a GraphQL response
sub _create_result {
    my ($self, $graphql_response, $entity_type) = @_;
    
    my $response = $self->_convert_response($graphql_response, $entity_type);
    return Net::Braintree::Result->new(response => $response);
}

# Transaction methods
sub create_transaction {
    my ($self, $params) = @_;
    
    my $amount = $params->{amount};
    my $payment_method_id = $params->{payment_method_token} || $params->{payment_method_nonce};
    my $options = $params->{options} || {};
    
    my $mutation = q{
        mutation ChargePaymentMethod($input: ChargePaymentMethodInput!) {
            chargePaymentMethod(input: $input) {
                transaction {
                    id
                    status
                    amount {
                        value
                        currencyIsoCode
                    }
                    createdAt
                    updatedAt
                    paymentMethod {
                        id
                    }
                    customer {
                        id
                    }
                }
            }
        }
    };
    
    my $variables = {
        input => {
            paymentMethodId => $payment_method_id,
            transaction => {
                amount => $amount,
                orderId => $params->{order_id},
                descriptor => $params->{descriptor},
                shipping => $params->{shipping},
                billing => $params->{billing},
                customer => $params->{customer},
                options => {
                    submitForSettlement => $options->{submit_for_settlement} || 0,
                }
            }
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'transaction');
}

sub find_transaction {
    my ($self, $id) = @_;
    
    my $query = q{
        query FindTransaction($id: ID!) {
            node(id: $id) {
                ... on Transaction {
                    id
                    status
                    amount {
                        value
                        currencyIsoCode
                    }
                    createdAt
                    updatedAt
                    paymentMethod {
                        id
                    }
                    customer {
                        id
                    }
                }
            }
        }
    };
    
    my $variables = {
        id => $id
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Reformat response to match expected structure
    if ($response->{data} && $response->{data}->{node}) {
        $response->{data}->{transaction} = $response->{data}->{node};
        delete $response->{data}->{node};
    }
    
    return $self->_create_result($response, 'transaction');
}

sub void_transaction {
    my ($self, $id) = @_;
    
    my $mutation = q{
        mutation VoidTransaction($input: VoidTransactionInput!) {
            voidTransaction(input: $input) {
                transaction {
                    id
                    status
                }
            }
        }
    };
    
    my $variables = {
        input => {
            transactionId => $id
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'transaction');
}

sub refund_transaction {
    my ($self, $id, $params) = @_;
    
    my $amount = $params->{amount} if $params;
    
    my $mutation = q{
        mutation RefundTransaction($input: RefundTransactionInput!) {
            refundTransaction(input: $input) {
                transaction {
                    id
                    status
                    amount {
                        value
                        currencyIsoCode
                    }
                }
            }
        }
    };
    
    my $variables = {
        input => {
            transactionId => $id
        }
    };
    
    if ($amount) {
        $variables->{input}->{amount} = $amount;
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'transaction');
}

# Customer methods
sub create_customer {
    my ($self, $params) = @_;
    
    my $mutation = q{
        mutation CreateCustomer($input: CreateCustomerInput!) {
            createCustomer(input: $input) {
                customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    createdAt
                    updatedAt
                }
            }
        }
    };
    
    my $variables = {
        input => {
            firstName => $params->{first_name},
            lastName => $params->{last_name},
            email => $params->{email},
            phone => $params->{phone},
            company => $params->{company},
            website => $params->{website}
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'customer');
}

sub find_customer {
    my ($self, $id) = @_;
    
    my $query = q{
        query FindCustomer($id: ID!) {
            node(id: $id) {
                ... on Customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    company
                    website
                    createdAt
                    updatedAt
                    paymentMethods {
                        edges {
                            node {
                                id
                            }
                        }
                    }
                }
            }
        }
    };
    
    my $variables = {
        id => $id
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Reformat response to match expected structure
    if ($response->{data} && $response->{data}->{node}) {
        $response->{data}->{customer} = $response->{data}->{node};
        delete $response->{data}->{node};
    }
    
    return $self->_create_result($response, 'customer');
}

# Payment method methods
sub create_payment_method {
    my ($self, $params) = @_;
    
    my $mutation = q{
        mutation TokenizePaymentMethod($input: TokenizePaymentMethodInput!) {
            tokenizePaymentMethod(input: $input) {
                paymentMethod {
                    id
                }
            }
        }
    };
    
    my $variables = {
        input => {
            paymentMethodNonce => $params->{payment_method_nonce},
            customerId => $params->{customer_id}
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'payment_method');
}

sub find_payment_method {
    my ($self, $token) = @_;
    
    my $query = q{
        query FindPaymentMethod($id: ID!) {
            node(id: $id) {
                ... on PaymentMethod {
                    id
                    createdAt
                    updatedAt
                    customerId
                }
            }
        }
    };
    
    my $variables = {
        id => $token
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Reformat response to match expected structure
    if ($response->{data} && $response->{data}->{node}) {
        $response->{data}->{payment_method} = $response->{data}->{node};
        delete $response->{data}->{node};
    }
    
    return $self->_create_result($response, 'payment_method');
}

1;
