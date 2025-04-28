package Net::Braintree::GraphQLGateway;

use Moose;
use Net::Braintree::GraphQL;
use Net::Braintree::Result;
use JSON;
use Carp qw(confess);

has 'config' => (is => 'ro', default => sub { Net::Braintree->configuration });
has 'graphql' => (is => 'ro', lazy => 1, default => sub { Net::Braintree::GraphQL->new(config => shift->config) });

# Convert REST-style response to GraphQL-style response with robust error handling
sub _convert_response {
    my ($self, $graphql_response, $entity_type) = @_;
    
    # Validate input parameters
    unless (defined $graphql_response) {
        confess "ConversionError: Cannot convert undefined GraphQL response";
    }
    
    unless (ref($graphql_response) eq 'HASH') {
        confess "ConversionError: GraphQL response must be a hash reference, got " . (ref($graphql_response) || 'scalar');
    }
    
    # If no entity type is specified, just return the data with validation
    unless (defined $entity_type) {
        return exists($graphql_response->{data}) ? $graphql_response->{data} : {};
    }
    
    # Create a response structure compatible with the existing SDK
    my $response = {};
    
    # Extract the relevant data from the GraphQL response with validation
    if (exists($graphql_response->{data}) && defined($graphql_response->{data}) && ref($graphql_response->{data}) eq 'HASH') {
        my $data = $graphql_response->{data};
        
        # Find the first key in the data object (should be the operation name)
        my @operations = keys %$data;
        
        if (@operations && defined($operations[0]) && exists($data->{$operations[0]}) && defined($data->{$operations[0]})) {
            my $operation = $operations[0];
            my $operation_data = $data->{$operation};
            
            # For most entity types, the data will be directly under the operation
            if ($entity_type eq 'transaction' && exists($operation_data->{transaction})) {
                $response->{transaction} = $operation_data->{transaction};
                
                # Convert GraphQL-style fields to REST-style for backward compatibility
                if (ref($response->{transaction}) eq 'HASH') {
                    # Handle nested amount objects
                    if (exists($response->{transaction}->{amount}) && 
                        ref($response->{transaction}->{amount}) eq 'HASH' && 
                        exists($response->{transaction}->{amount}->{value})) {
                        $response->{transaction}->{amount} = $response->{transaction}->{amount}->{value};
                    }
                    
                    # Convert camelCase to snake_case for backward compatibility
                    if (exists($response->{transaction}->{orderId})) {
                        $response->{transaction}->{order_id} = $response->{transaction}->{orderId};
                    }
                    
                    if (exists($response->{transaction}->{merchantAccountId})) {
                        $response->{transaction}->{merchant_account_id} = $response->{transaction}->{merchantAccountId};
                    }
                }
            }
            elsif ($entity_type eq 'customer' && exists($operation_data->{customer})) {
                $response->{customer} = $operation_data->{customer};
                
                # Convert GraphQL-style fields to REST-style for backward compatibility
                if (ref($response->{customer}) eq 'HASH') {
                    if (exists($response->{customer}->{firstName})) {
                        $response->{customer}->{first_name} = $response->{customer}->{firstName};
                    }
                    
                    if (exists($response->{customer}->{lastName})) {
                        $response->{customer}->{last_name} = $response->{customer}->{lastName};
                    }
                }
            }
            elsif ($entity_type eq 'credit_card' && exists($operation_data->{creditCard})) {
                $response->{credit_card} = $operation_data->{creditCard};
                
                # Convert GraphQL-style fields to REST-style for backward compatibility
                if (ref($response->{credit_card}) eq 'HASH') {
                    if (exists($response->{credit_card}->{expirationMonth})) {
                        $response->{credit_card}->{expiration_month} = $response->{credit_card}->{expirationMonth};
                    }
                    
                    if (exists($response->{credit_card}->{expirationYear})) {
                        $response->{credit_card}->{expiration_year} = $response->{credit_card}->{expirationYear};
                    }
                    
                    if (exists($response->{credit_card}->{cardholderName})) {
                        $response->{credit_card}->{cardholder_name} = $response->{credit_card}->{cardholderName};
                    }
                }
            }
            elsif ($entity_type eq 'payment_method' && exists($operation_data->{paymentMethod})) {
                $response->{payment_method} = $operation_data->{paymentMethod};
                
                # Convert GraphQL-style fields to REST-style for backward compatibility
                if (ref($response->{payment_method}) eq 'HASH') {
                    if (exists($response->{payment_method}->{customerId})) {
                        $response->{payment_method}->{customer_id} = $response->{payment_method}->{customerId};
                    }
                }
            }
            else {
                # Default case - just use the operation result
                $response->{$entity_type} = $operation_data;
            }
        }
    }
    
    return $response;
}

# Create a result object from a GraphQL response with validation
sub _create_result {
    my ($self, $graphql_response, $entity_type) = @_;
    
    # Validate input parameters
    unless (defined $graphql_response) {
        confess "ResultError: Cannot create result from undefined GraphQL response";
    }
    
    # Handle error responses explicitly
    if (exists($graphql_response->{errors}) && ref($graphql_response->{errors}) eq 'ARRAY' && @{$graphql_response->{errors}}) {
        my $error = $graphql_response->{errors}->[0];
        my $message = $error->{message} || 'Unknown GraphQL error';
        my $error_class = $error->{extensions}->{errorClass} || 'GraphQLError';
        
        # Create an error result that matches the format expected by the SDK
        return Net::Braintree::Result->new(response => {
            success => 0,
            message => $message,
            errors => {
                errors => [{
                    code => $error_class,
                    message => $message,
                    attribute => $error->{extensions}->{inputPath} || ''
                }]
            }
        });
    }
    
    # Convert the response to the expected format
    my $response = $self->_convert_response($graphql_response, $entity_type);
    
    # Add success flag for consistency with REST API responses
    if (ref($response) eq 'HASH') {
        $response->{success} = 1 unless exists($response->{success});
    }
    
    return Net::Braintree::Result->new(response => $response);
}

# Client token methods
sub generate_client_token {
    my ($self, $params) = @_;
    
    my $mutation = q{
        mutation CreateClientToken($input: CreateClientTokenInput!) {
            createClientToken(input: $input) {
                clientToken
            }
        }
    };
    
    my $variables = {
        input => {
            clientToken => {
                merchantAccountId => $params->{merchant_account_id},
                customerId => $params->{customer_id},
                version => 3
            }
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Format response to match expected structure
    if ($response->{data} && $response->{data}->{createClientToken}) {
        return { client_token => $response->{data}->{createClientToken}->{clientToken} };
    }
    
    return { error => "Failed to generate client token" };
}

# Transaction methods
sub submit_for_settlement {
    my ($self, $id, $params) = @_;
    
    my $mutation = q{
        mutation SubmitForSettlement($input: SubmitForSettlementInput!) {
            submitForSettlement(input: $input) {
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
    
    if ($params && $params->{amount}) {
        $variables->{input}->{amount} = $params->{amount};
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'transaction');
}

sub hold_transaction_in_escrow {
    my ($self, $id) = @_;
    
    my $mutation = q{
        mutation HoldInEscrow($input: HoldInEscrowInput!) {
            holdInEscrow(input: $input) {
                transaction {
                    id
                    status
                    escrowStatus
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

sub release_transaction_from_escrow {
    my ($self, $id) = @_;
    
    my $mutation = q{
        mutation ReleaseFromEscrow($input: ReleaseFromEscrowInput!) {
            releaseFromEscrow(input: $input) {
                transaction {
                    id
                    status
                    escrowStatus
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

sub cancel_transaction_release {
    my ($self, $id) = @_;
    
    my $mutation = q{
        mutation CancelRelease($input: CancelReleaseInput!) {
            cancelRelease(input: $input) {
                transaction {
                    id
                    status
                    escrowStatus
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

sub clone_transaction {
    my ($self, $id, $params) = @_;
    
    my $mutation = q{
        mutation CloneTransaction($input: CloneTransactionInput!) {
            cloneTransaction(input: $input) {
                transaction {
                    id
                    status
                    amount {
                        value
                        currencyIsoCode
                    }
                    type
                }
            }
        }
    };
    
    my $variables = {
        input => {
            transactionId => $id,
            amount => $params->{amount}
        }
    };
    
    # Add optional parameters if present
    if ($params->{options}) {
        $variables->{input}->{options} = $params->{options};
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'transaction');
}

sub search_transactions {
    my ($self, $search_params) = @_;
    
    # Convert the search parameters to GraphQL format
    my $query_params = {};
    
    # Map common search parameters
    if ($search_params->{id}) {
        $query_params->{id} = $search_params->{id};
    }
    
    if ($search_params->{status}) {
        $query_params->{status} = $search_params->{status};
    }
    
    if ($search_params->{type}) {
        $query_params->{type} = $search_params->{type};
    }
    
    if ($search_params->{amount}) {
        $query_params->{amount} = $search_params->{amount};
    }
    
    # Date ranges
    if ($search_params->{created_at}) {
        $query_params->{createdAt} = $search_params->{created_at};
    }
    
    my $query = q{
        query SearchTransactions($searchParams: TransactionSearchInput!) {
            search {
                transactions(input: $searchParams) {
                    edges {
                        node {
                            id
                            status
                            type
                            amount {
                                value
                                currencyIsoCode
                            }
                            createdAt
                            updatedAt
                            orderId
                            paymentMethod {
                                id
                            }
                            customer {
                                id
                            }
                        }
                    }
                    pageInfo {
                        hasNextPage
                        endCursor
                    }
                }
            }
        }
    };
    
    my $variables = {
        searchParams => $query_params
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{search} && $response->{data}->{search}->{transactions}) {
        my $transactions = [];
        foreach my $edge (@{$response->{data}->{search}->{transactions}->{edges}}) {
            push @$transactions, $edge->{node};
        }
        $result->{transactions} = $transactions;
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub get_all_transactions {
    my ($self) = @_;
    
    # This is a simplified version that gets a limited number of transactions
    # In a real implementation, you would need to handle pagination
    my $query = q{
        query GetAllTransactions {
            search {
                transactions {
                    edges {
                        node {
                            id
                            status
                            type
                            amount {
                                value
                                currencyIsoCode
                            }
                            createdAt
                            updatedAt
                            orderId
                            paymentMethod {
                                id
                            }
                            customer {
                                id
                            }
                        }
                    }
                    pageInfo {
                        hasNextPage
                        endCursor
                    }
                }
            }
        }
    };
    
    my $response = $self->graphql->query($query);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{search} && $response->{data}->{search}->{transactions}) {
        my $transactions = [];
        foreach my $edge (@{$response->{data}->{search}->{transactions}->{edges}}) {
            push @$transactions, $edge->{node};
        }
        $result->{transactions} = $transactions;
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub create_transaction {
    my ($self, $params) = @_;
    
    # Validate required parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_transaction";
    }
    
    unless (exists($params->{amount}) && defined($params->{amount}) && $params->{amount} =~ /^\d+(\.\d+)?$/) {
        confess "ValidationError: Invalid amount for create_transaction";
    }
    
    unless (exists($params->{payment_method_token}) || exists($params->{payment_method_nonce})) {
        confess "ValidationError: Missing required parameter 'payment_method_token' or 'payment_method_nonce' for create_transaction";
    }
    
    # Sanitize and prepare parameters
    my $amount = $params->{amount};
    my $payment_method_id = $params->{payment_method_token} || $params->{payment_method_nonce};
    my $options = $params->{options} || {};
    
    my $mutation = q{
        mutation ChargePaymentMethod($input: ChargePaymentMethodInput!) {
            chargePaymentMethod(input: $input) {
                transaction {
                    id
                    status
                    type
                    currencyIsoCode
                    amount {
                        value
                        currencyIsoCode
                    }
                    merchantAccountId
                    orderId
                    purchaseOrderNumber
                    taxAmount {
                        value
                        currencyIsoCode
                    }
                    shippingAmount {
                        value
                        currencyIsoCode
                    }
                    discountAmount {
                        value
                        currencyIsoCode
                    }
                    createdAt
                    updatedAt
                    paymentMethod {
                        id
                        ... on CreditCard {
                            bin
                            last4
                            cardType
                            expirationMonth
                            expirationYear
                            cardholderName
                        }
                    }
                    customer {
                        id
                        firstName
                        lastName
                        email
                    }
                    billing {
                        firstName
                        lastName
                        company
                        streetAddress
                        extendedAddress
                        locality
                        region
                        postalCode
                        countryCodeAlpha2
                    }
                    shipping {
                        firstName
                        lastName
                        company
                        streetAddress
                        extendedAddress
                        locality
                        region
                        postalCode
                        countryCodeAlpha2
                    }
                    statusHistory {
                        timestamp
                        status
                    }
                    processorResponseCode
                    processorResponseText
                    additionalProcessorResponse
                    riskData {
                        id
                        decision
                        deviceDataCaptured
                        fraudServiceProvider
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
                purchaseOrderNumber => $params->{purchase_order_number},
                merchantAccountId => $params->{merchant_account_id},
                descriptor => $params->{descriptor},
                shipping => $params->{shipping},
                billing => $params->{billing},
                customer => $params->{customer},
                taxAmount => $params->{tax_amount},
                shippingAmount => $params->{shipping_amount},
                discountAmount => $params->{discount_amount},
                options => {
                    submitForSettlement => $options->{submit_for_settlement} || 0,
                    storeInVault => $options->{store_in_vault} || 0,
                    storeInVaultOnSuccess => $options->{store_in_vault_on_success} || 0,
                    addBillingAddressToPaymentMethod => $options->{add_billing_address_to_payment_method} || 0,
                    storeShippingAddressInVault => $options->{store_shipping_address_in_vault} || 0,
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

# Customer methods
sub create_customer {
    my ($self, $params) = @_;
    
    # Validate required parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_customer";
    }
    
    my $mutation = q{
        mutation CreateCustomer($input: CustomerCreateInput!) {
            createCustomer(input: $input) {
                customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    company
                    website
                    createdAt
                    updatedAt
                }
            }
        }
    };
    
    my $variables = {
        input => {}
    };
    
    # Map the parameters to GraphQL format
    if ($params->{first_name}) {
        $variables->{input}->{firstName} = $params->{first_name};
    }
    
    if ($params->{last_name}) {
        $variables->{input}->{lastName} = $params->{last_name};
    }
    
    if ($params->{email}) {
        $variables->{input}->{email} = $params->{email};
    }
    
    if ($params->{phone}) {
        $variables->{input}->{phone} = $params->{phone};
    }
    
    if ($params->{company}) {
        $variables->{input}->{company} = $params->{company};
    }
    
    if ($params->{website}) {
        $variables->{input}->{website} = $params->{website};
    }
    
    # Handle payment methods if provided
    if ($params->{credit_card}) {
        $variables->{input}->{creditCard} = $self->_format_credit_card_input($params->{credit_card});
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'customer');
}

sub find_customer {
    my ($self, $id) = @_;
    
    # Validate required parameters
    unless (defined $id && $id ne '') {
        confess "ValidationError: Missing customer ID for find_customer";
    }
    
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
                                ... on CreditCard {
                                    bin
                                    last4
                                    cardType
                                    expirationMonth
                                    expirationYear
                                    cardholderName
                                    isDefault
                                    isExpired
                                }
                                ... on PayPalAccount {
                                    email
                                    isDefault
                                }
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
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{node}) {
        $result->{customer} = $response->{data}->{node};
        
        # Convert payment methods to the expected format
        if ($response->{data}->{node}->{paymentMethods} && $response->{data}->{node}->{paymentMethods}->{edges}) {
            my $credit_cards = [];
            my $paypal_accounts = [];
            
            foreach my $edge (@{$response->{data}->{node}->{paymentMethods}->{edges}}) {
                my $node = $edge->{node};
                
                if ($node->{cardType}) {
                    # This is a credit card
                    push @$credit_cards, $node;
                } elsif ($node->{email}) {
                    # This is a PayPal account
                    push @$paypal_accounts, $node;
                }
            }
            
            $result->{customer}->{credit_cards} = $credit_cards;
            $result->{customer}->{paypal_accounts} = $paypal_accounts;
        }
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub update_customer {
    my ($self, $id, $params) = @_;
    
    # Validate required parameters
    unless (defined $id && $id ne '') {
        confess "ValidationError: Missing customer ID for update_customer";
    }
    
    unless (defined $params) {
        confess "ValidationError: Missing parameters for update_customer";
    }
    
    my $mutation = q{
        mutation UpdateCustomer($input: CustomerUpdateInput!) {
            updateCustomer(input: $input) {
                customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    company
                    website
                    createdAt
                    updatedAt
                }
            }
        }
    };
    
    my $variables = {
        input => {
            id => $id
        }
    };
    
    # Map the parameters to GraphQL format
    if ($params->{first_name}) {
        $variables->{input}->{firstName} = $params->{first_name};
    }
    
    if ($params->{last_name}) {
        $variables->{input}->{lastName} = $params->{last_name};
    }
    
    if ($params->{email}) {
        $variables->{input}->{email} = $params->{email};
    }
    
    if ($params->{phone}) {
        $variables->{input}->{phone} = $params->{phone};
    }
    
    if ($params->{company}) {
        $variables->{input}->{company} = $params->{company};
    }
    
    if ($params->{website}) {
        $variables->{input}->{website} = $params->{website};
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'customer');
}

sub delete_customer {
    my ($self, $id) = @_;
    
    # Validate required parameters
    unless (defined $id && $id ne '') {
        confess "ValidationError: Missing customer ID for delete_customer";
    }
    
    my $mutation = q{
        mutation DeleteCustomer($input: CustomerDeleteInput!) {
            deleteCustomer(input: $input) {
                id
            }
        }
    };
    
    my $variables = {
        input => {
            id => $id
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Create a success result
    my $result = {
        success => 1
    };
    
    if ($response->{data} && $response->{data}->{deleteCustomer} && $response->{data}->{deleteCustomer}->{id}) {
        $result->{customer} = { id => $response->{data}->{deleteCustomer}->{id} };
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub search_customers {
    my ($self, $search_params) = @_;
    
    # Convert the search parameters to GraphQL format
    my $query_params = {};
    
    # Map common search parameters
    if ($search_params->{id}) {
        $query_params->{id} = $search_params->{id};
    }
    
    if ($search_params->{first_name}) {
        $query_params->{firstName} = $search_params->{first_name};
    }
    
    if ($search_params->{last_name}) {
        $query_params->{lastName} = $search_params->{last_name};
    }
    
    if ($search_params->{email}) {
        $query_params->{email} = $search_params->{email};
    }
    
    if ($search_params->{phone}) {
        $query_params->{phone} = $search_params->{phone};
    }
    
    if ($search_params->{created_at}) {
        $query_params->{createdAt} = $search_params->{created_at};
    }
    
    my $query = q{
        query SearchCustomers($searchParams: CustomerSearchInput!) {
            search {
                customers(input: $searchParams) {
                    edges {
                        node {
                            id
                            firstName
                            lastName
                            email
                            phone
                            company
                            website
                            createdAt
                            updatedAt
                        }
                    }
                    pageInfo {
                        hasNextPage
                        endCursor
                    }
                }
            }
        }
    };
    
    my $variables = {
        searchParams => $query_params
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{search} && $response->{data}->{search}->{customers}) {
        my $customers = [];
        foreach my $edge (@{$response->{data}->{search}->{customers}->{edges}}) {
            push @$customers, $edge->{node};
        }
        $result->{customers} = $customers;
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub get_all_customers {
    my ($self) = @_;
    
    # This is a simplified version that gets a limited number of customers
    # In a real implementation, you would need to handle pagination
    my $query = q{
        query GetAllCustomers {
            search {
                customers {
                    edges {
                        node {
                            id
                            firstName
                            lastName
                            email
                            phone
                            company
                            website
                            createdAt
                            updatedAt
                        }
                    }
                    pageInfo {
                        hasNextPage
                        endCursor
                    }
                }
            }
        }
    };
    
    my $response = $self->graphql->query($query);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{search} && $response->{data}->{search}->{customers}) {
        my $customers = [];
        foreach my $edge (@{$response->{data}->{search}->{customers}->{edges}}) {
            push @$customers, $edge->{node};
        }
        $result->{customers} = $customers;
    }
    
    return Net::Braintree::Result->new(response => $result);
}

# Credit Card methods
sub create_credit_card {
    my ($self, $params) = @_;
    
    # Validate required parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_credit_card";
    }
    
    unless (defined $params->{customer_id} && $params->{customer_id} ne '') {
        confess "ValidationError: Missing customer_id for create_credit_card";
    }
    
    my $mutation = q{
        mutation CreateCreditCard($input: CreditCardCreateInput!) {
            createCreditCard(input: $input) {
                creditCard {
                    id
                    bin
                    last4
                    cardType
                    expirationMonth
                    expirationYear
                    cardholderName
                    isDefault
                    isExpired
                    customerId
                }
            }
        }
    };
    
    my $variables = {
        input => {
            customerId => $params->{customer_id},
            creditCard => $self->_format_credit_card_input($params)
        }
    };
    
    # Handle options if provided
    if ($params->{options}) {
        if (defined $params->{options}->{make_default}) {
            $variables->{input}->{creditCard}->{isDefault} = $params->{options}->{make_default} ? JSON::true : JSON::false;
        }
        
        if (defined $params->{options}->{verification_merchant_account_id}) {
            $variables->{input}->{verificationMerchantAccountId} = $params->{options}->{verification_merchant_account_id};
        }
        
        if (defined $params->{options}->{verify_card}) {
            $variables->{input}->{verifyCard} = $params->{options}->{verify_card} ? JSON::true : JSON::false;
        }
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{createCreditCard}) {
        $result->{credit_card} = $response->{data}->{createCreditCard}->{creditCard};
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub update_credit_card {
    my ($self, $token, $params) = @_;
    
    # Validate required parameters
    unless (defined $token && $token ne '') {
        confess "ValidationError: Missing token for update_credit_card";
    }
    
    unless (defined $params) {
        confess "ValidationError: Missing parameters for update_credit_card";
    }
    
    my $mutation = q{
        mutation UpdateCreditCard($input: CreditCardUpdateInput!) {
            updateCreditCard(input: $input) {
                creditCard {
                    id
                    bin
                    last4
                    cardType
                    expirationMonth
                    expirationYear
                    cardholderName
                    isDefault
                    isExpired
                    customerId
                }
            }
        }
    };
    
    my $variables = {
        input => {
            id => $token
        }
    };
    
    # Map the parameters to GraphQL format
    if ($params->{number}) {
        $variables->{input}->{number} = $params->{number};
    }
    
    if ($params->{expiration_month}) {
        $variables->{input}->{expirationMonth} = $params->{expiration_month};
    }
    
    if ($params->{expiration_year}) {
        $variables->{input}->{expirationYear} = $params->{expiration_year};
    }
    
    if ($params->{cvv}) {
        $variables->{input}->{cvv} = $params->{cvv};
    }
    
    if ($params->{cardholder_name}) {
        $variables->{input}->{cardholderName} = $params->{cardholder_name};
    }
    
    # Handle options if provided
    if ($params->{options}) {
        if (defined $params->{options}->{make_default}) {
            $variables->{input}->{isDefault} = $params->{options}->{make_default} ? JSON::true : JSON::false;
        }
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{updateCreditCard}) {
        $result->{credit_card} = $response->{data}->{updateCreditCard}->{creditCard};
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub find_credit_card {
    my ($self, $token) = @_;
    
    # Validate required parameters
    unless (defined $token && $token ne '') {
        confess "ValidationError: Missing token for find_credit_card";
    }
    
    my $query = q{
        query FindCreditCard($id: ID!) {
            node(id: $id) {
                ... on CreditCard {
                    id
                    bin
                    last4
                    cardType
                    expirationMonth
                    expirationYear
                    cardholderName
                    isDefault
                    isExpired
                    customerId
                    billingAddress {
                        id
                        firstName
                        lastName
                        company
                        streetAddress
                        extendedAddress
                        locality
                        region
                        postalCode
                        countryCodeAlpha2
                    }
                }
            }
        }
    };
    
    my $variables = {
        id => $token
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{node}) {
        $result->{credit_card} = $response->{data}->{node};
        
        # Convert billing address to the expected format if present
        if ($response->{data}->{node}->{billingAddress}) {
            $result->{credit_card}->{billing_address} = $response->{data}->{node}->{billingAddress};
            delete $result->{credit_card}->{billingAddress};
        }
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub credit_card_from_nonce {
    my ($self, $nonce) = @_;
    
    # Validate required parameters
    unless (defined $nonce && $nonce ne '') {
        confess "ValidationError: Missing nonce for credit_card_from_nonce";
    }
    
    my $query = q{
        query CreditCardFromNonce($nonce: String!) {
            paymentMethodFromNonce(nonce: $nonce) {
                ... on CreditCard {
                    id
                    bin
                    last4
                    cardType
                    expirationMonth
                    expirationYear
                    cardholderName
                    isDefault
                    isExpired
                    customerId
                }
            }
        }
    };
    
    my $variables = {
        nonce => $nonce
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Convert the response to match the expected format
    my $result = {};
    if ($response->{data} && $response->{data}->{paymentMethodFromNonce}) {
        $result->{credit_card} = $response->{data}->{paymentMethodFromNonce};
    }
    
    return Net::Braintree::Result->new(response => $result);
}

# Payment Method methods
sub create_payment_method {
    my ($self, $params) = @_;
    
    # Validate required parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_payment_method";
    }
    
    unless (defined $params->{customer_id} && $params->{customer_id} ne '') {
        confess "ValidationError: Missing customer_id for create_payment_method";
    }
    
    # Determine the type of payment method
    my $mutation;
    my $variables = {
        input => {
            customerId => $params->{customer_id}
        }
    };
    
    if ($params->{payment_method_nonce}) {
        # Creating from a payment method nonce
        $variables->{input}->{paymentMethodNonce} = $params->{payment_method_nonce};
        
        $mutation = q{
            mutation CreatePaymentMethod($input: PaymentMethodCreateInput!) {
                createPaymentMethod(input: $input) {
                    paymentMethod {
                        id
                        ... on CreditCard {
                            bin
                            last4
                            cardType
                            expirationMonth
                            expirationYear
                            cardholderName
                            isDefault
                            isExpired
                            customerId
                        }
                        ... on PayPalAccount {
                            email
                            isDefault
                            customerId
                        }
                    }
                }
            }
        };
    } elsif ($params->{credit_card}) {
        # Creating a credit card directly
        $variables->{input}->{creditCard} = $self->_format_credit_card_input($params->{credit_card});
        
        if ($params->{credit_card}->{options} && $params->{credit_card}->{options}->{make_default}) {
            $variables->{input}->{creditCard}->{isDefault} = $params->{credit_card}->{options}->{make_default} ? JSON::true : JSON::false;
        }
        
        $mutation = q{
            mutation CreateCreditCard($input: CreditCardCreateInput!) {
                createCreditCard(input: $input) {
                    creditCard {
                        id
                        bin
                        last4
                        cardType
                        expirationMonth
                        expirationYear
                        cardholderName
                        isDefault
                        isExpired
                        customerId
                    }
                }
            }
        };
    } elsif ($params->{paypal_account}) {
        # Creating a PayPal account
        $variables->{input}->{paypalAccount} = {
            email => $params->{paypal_account}->{email}
        };
        
        if ($params->{paypal_account}->{options} && $params->{paypal_account}->{options}->{make_default}) {
            $variables->{input}->{paypalAccount}->{isDefault} = $params->{paypal_account}->{options}->{make_default} ? JSON::true : JSON::false;
        }
        
        $mutation = q{
            mutation CreatePayPalAccount($input: PayPalAccountCreateInput!) {
                createPayPalAccount(input: $input) {
                    paypalAccount {
                        id
                        email
                        isDefault
                        customerId
                    }
                }
            }
        };
    } else {
        confess "ValidationError: Missing payment method details for create_payment_method";
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Determine the type of payment method from the response
    my $result = {};
    if ($response->{data}) {
        if ($response->{data}->{createPaymentMethod}) {
            $result->{payment_method} = $response->{data}->{createPaymentMethod}->{paymentMethod};
        } elsif ($response->{data}->{createCreditCard}) {
            $result->{credit_card} = $response->{data}->{createCreditCard}->{creditCard};
        } elsif ($response->{data}->{createPayPalAccount}) {
            $result->{paypal_account} = $response->{data}->{createPayPalAccount}->{paypalAccount};
        }
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub find_payment_method {
    my ($self, $token) = @_;
    
    # Validate required parameters
    unless (defined $token && $token ne '') {
        confess "ValidationError: Missing token for find_payment_method";
    }
    
    my $query = q{
        query FindPaymentMethod($id: ID!) {
            node(id: $id) {
                ... on PaymentMethod {
                    id
                    ... on CreditCard {
                        bin
                        last4
                        cardType
                        expirationMonth
                        expirationYear
                        cardholderName
                        isDefault
                        isExpired
                        customerId
                    }
                    ... on PayPalAccount {
                        email
                        isDefault
                        customerId
                    }
                }
            }
        }
    };
    
    my $variables = {
        id => $token
    };
    
    my $response = $self->graphql->query($query, $variables);
    
    # Determine the type of payment method from the response
    my $result = {};
    if ($response->{data} && $response->{data}->{node}) {
        my $node = $response->{data}->{node};
        
        if ($node->{cardType}) {
            # This is a credit card
            $result->{credit_card} = $node;
        } elsif ($node->{email}) {
            # This is a PayPal account
            $result->{paypal_account} = $node;
        } else {
            # Generic payment method
            $result->{payment_method} = $node;
        }
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub update_payment_method {
    my ($self, $token, $params) = @_;
    
    # Validate required parameters
    unless (defined $token && $token ne '') {
        confess "ValidationError: Missing token for update_payment_method";
    }
    
    unless (defined $params) {
        confess "ValidationError: Missing parameters for update_payment_method";
    }
    
    # Determine the type of payment method from the parameters
    my $mutation;
    my $variables = {
        input => {
            id => $token
        }
    };
    
    if ($params->{credit_card}) {
        # Updating a credit card
        if ($params->{credit_card}->{number}) {
            $variables->{input}->{number} = $params->{credit_card}->{number};
        }
        
        if ($params->{credit_card}->{expiration_month}) {
            $variables->{input}->{expirationMonth} = $params->{credit_card}->{expiration_month};
        }
        
        if ($params->{credit_card}->{expiration_year}) {
            $variables->{input}->{expirationYear} = $params->{credit_card}->{expiration_year};
        }
        
        if ($params->{credit_card}->{cvv}) {
            $variables->{input}->{cvv} = $params->{credit_card}->{cvv};
        }
        
        if ($params->{credit_card}->{cardholder_name}) {
            $variables->{input}->{cardholderName} = $params->{credit_card}->{cardholder_name};
        }
        
        if ($params->{credit_card}->{options} && defined $params->{credit_card}->{options}->{make_default}) {
            $variables->{input}->{isDefault} = $params->{credit_card}->{options}->{make_default} ? JSON::true : JSON::false;
        }
        
        $mutation = q{
            mutation UpdateCreditCard($input: CreditCardUpdateInput!) {
                updateCreditCard(input: $input) {
                    creditCard {
                        id
                        bin
                        last4
                        cardType
                        expirationMonth
                        expirationYear
                        cardholderName
                        isDefault
                        isExpired
                        customerId
                    }
                }
            }
        };
    } elsif ($params->{paypal_account}) {
        # Updating a PayPal account
        if ($params->{paypal_account}->{options} && defined $params->{paypal_account}->{options}->{make_default}) {
            $variables->{input}->{isDefault} = $params->{paypal_account}->{options}->{make_default} ? JSON::true : JSON::false;
        }
        
        $mutation = q{
            mutation UpdatePayPalAccount($input: PayPalAccountUpdateInput!) {
                updatePayPalAccount(input: $input) {
                    paypalAccount {
                        id
                        email
                        isDefault
                        customerId
                    }
                }
            }
        };
    } else {
        confess "ValidationError: Missing payment method details for update_payment_method";
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Determine the type of payment method from the response
    my $result = {};
    if ($response->{data}) {
        if ($response->{data}->{updateCreditCard}) {
            $result->{credit_card} = $response->{data}->{updateCreditCard}->{creditCard};
        } elsif ($response->{data}->{updatePayPalAccount}) {
            $result->{paypal_account} = $response->{data}->{updatePayPalAccount}->{paypalAccount};
        }
    }
    
    return Net::Braintree::Result->new(response => $result);
}

sub delete_payment_method {
    my ($self, $token) = @_;
    
    # Validate required parameters
    unless (defined $token && $token ne '') {
        confess "ValidationError: Missing token for delete_payment_method";
    }
    
    my $mutation = q{
        mutation DeletePaymentMethod($input: PaymentMethodDeleteInput!) {
            deletePaymentMethod(input: $input) {
                id
            }
        }
    };
    
    my $variables = {
        input => {
            id => $token
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Create a success result
    my $result = {
        success => 1
    };
    
    if ($response->{data} && $response->{data}->{deletePaymentMethod} && $response->{data}->{deletePaymentMethod}->{id}) {
        $result->{payment_method} = { id => $response->{data}->{deletePaymentMethod}->{id} };
    }
    
    return Net::Braintree::Result->new(response => $result);
}

# Helper method to format credit card input
sub _format_credit_card_input {
    my ($self, $credit_card) = @_;
    
    my $formatted = {};
    
    if ($credit_card->{number}) {
        $formatted->{number} = $credit_card->{number};
    }
    
    if ($credit_card->{expiration_month}) {
        $formatted->{expirationMonth} = $credit_card->{expiration_month};
    }
    
    if ($credit_card->{expiration_year}) {
        $formatted->{expirationYear} = $credit_card->{expiration_year};
    }
    
    if ($credit_card->{cvv}) {
        $formatted->{cvv} = $credit_card->{cvv};
    }
    
    if ($credit_card->{cardholder_name}) {
        $formatted->{cardholderName} = $credit_card->{cardholder_name};
    }
    
    return $formatted;
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
    
    # Validate parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_customer";
    }
    
    # Sanitize input parameters to prevent injection
    foreach my $key (keys %$params) {
        if (defined $params->{$key} && !ref($params->{$key})) {
            # Remove any control characters
            $params->{$key} =~ s/[\x00-\x1F\x7F]//g;
        }
    }
    
    my $mutation = q{
        mutation CreateCustomer($input: CreateCustomerInput!) {
            createCustomer(input: $input) {
                customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    company
                    website
                    fax
                    createdAt
                    updatedAt
                    customFields
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
            website => $params->{website},
            fax => $params->{fax},
            customFields => $params->{custom_fields}
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'customer');
}

sub update_customer {
    my ($self, $id, $params) = @_;
    
    my $mutation = q{
        mutation UpdateCustomer($input: UpdateCustomerInput!) {
            updateCustomer(input: $input) {
                customer {
                    id
                    firstName
                    lastName
                    email
                    phone
                    company
                    website
                    fax
                    createdAt
                    updatedAt
                    customFields
                }
            }
        }
    };
    
    my $variables = {
        input => {
            id => $id,
            firstName => $params->{first_name},
            lastName => $params->{last_name},
            email => $params->{email},
            phone => $params->{phone},
            company => $params->{company},
            website => $params->{website},
            fax => $params->{fax},
            customFields => $params->{custom_fields}
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'customer');
}

sub delete_customer {
    my ($self, $id) = @_;
    
    my $mutation = q{
        mutation DeleteCustomer($input: DeleteCustomerInput!) {
            deleteCustomer(input: $input) {
                id
            }
        }
    };
    
    my $variables = {
        input => {
            id => $id
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Format response to match expected structure
    if ($response->{data} && $response->{data}->{deleteCustomer}) {
        return Net::Braintree::Result->new(response => { success => 1 });
    }
    
    return Net::Braintree::Result->new(response => { success => 0 });
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
    
    # Validate required parameters
    unless (defined $params) {
        confess "ValidationError: Missing parameters for create_payment_method";
    }
    
    unless (exists($params->{payment_method_nonce}) && defined($params->{payment_method_nonce})) {
        confess "ValidationError: Missing required parameter 'payment_method_nonce' for create_payment_method";
    }
    
    # Sanitize customer_id if present
    if (exists($params->{customer_id}) && defined($params->{customer_id})) {
        # Ensure customer_id contains only valid characters
        unless ($params->{customer_id} =~ /^[a-zA-Z0-9_-]+$/) {
            confess "ValidationError: Invalid customer_id format";
        }
    }
    
    my $mutation = q{
        mutation TokenizePaymentMethod($input: TokenizePaymentMethodInput!) {
            tokenizePaymentMethod(input: $input) {
                paymentMethod {
                    id
                    createdAt
                    updatedAt
                    customerId
                    ... on CreditCard {
                        bin
                        last4
                        cardType
                        expirationMonth
                        expirationYear
                        cardholderName
                        issuingBank
                        countryOfIssuance
                        isNetworkTokenized
                        isDefault
                        imageUrl
                        billingAddress {
                            id
                            firstName
                            lastName
                            company
                            streetAddress
                            extendedAddress
                            locality
                            region
                            postalCode
                            countryCodeAlpha2
                        }
                    }
                    ... on PayPalAccount {
                        email
                        isDefault
                        imageUrl
                        billingAgreementId
                    }
                    ... on VenmoAccount {
                        username
                        isDefault
                        imageUrl
                    }
                }
            }
        }
    };
    
    my $variables = {
        input => {
            paymentMethodNonce => $params->{payment_method_nonce},
            customerId => $params->{customer_id},
            options => {
                failOnDuplicatePaymentMethod => $params->{options}->{fail_on_duplicate_payment_method} || 0,
                makeDefault => $params->{options}->{make_default} || 0,
                verifyCard => $params->{options}->{verify_card} || 0,
                verificationMerchantAccountId => $params->{options}->{verification_merchant_account_id}
            }
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'payment_method');
}

sub update_payment_method {
    my ($self, $token, $params) = @_;
    
    my $mutation = q{
        mutation UpdatePaymentMethod($input: UpdatePaymentMethodInput!) {
            updatePaymentMethod(input: $input) {
                paymentMethod {
                    id
                    ... on CreditCard {
                        bin
                        last4
                        cardType
                        expirationMonth
                        expirationYear
                        cardholderName
                        isDefault
                        billingAddress {
                            id
                            firstName
                            lastName
                            company
                            streetAddress
                            extendedAddress
                            locality
                            region
                            postalCode
                            countryCodeAlpha2
                        }
                    }
                }
            }
        }
    };
    
    my $variables = {
        input => {
            paymentMethodId => $token,
            options => {
                makeDefault => $params->{options}->{make_default} || 0
            }
        }
    };
    
    # Add credit card specific fields if present
    if ($params->{cardholder_name} || $params->{expiration_month} || $params->{expiration_year}) {
        $variables->{input}->{creditCard} = {
            cardholderName => $params->{cardholder_name},
            expirationMonth => $params->{expiration_month},
            expirationYear => $params->{expiration_year}
        };
    }
    
    # Add billing address if present
    if ($params->{billing_address}) {
        $variables->{input}->{billingAddress} = {
            firstName => $params->{billing_address}->{first_name},
            lastName => $params->{billing_address}->{last_name},
            company => $params->{billing_address}->{company},
            streetAddress => $params->{billing_address}->{street_address},
            extendedAddress => $params->{billing_address}->{extended_address},
            locality => $params->{billing_address}->{locality},
            region => $params->{billing_address}->{region},
            postalCode => $params->{billing_address}->{postal_code},
            countryCodeAlpha2 => $params->{billing_address}->{country_code_alpha2}
        };
    }
    
    my $response = $self->graphql->mutate($mutation, $variables);
    return $self->_create_result($response, 'payment_method');
}

sub delete_payment_method {
    my ($self, $token) = @_;
    
    my $mutation = q{
        mutation DeletePaymentMethod($input: DeletePaymentMethodInput!) {
            deletePaymentMethod(input: $input) {
                id
            }
        }
    };
    
    my $variables = {
        input => {
            paymentMethodId => $token
        }
    };
    
    my $response = $self->graphql->mutate($mutation, $variables);
    
    # Format response to match expected structure
    if ($response->{data} && $response->{data}->{deletePaymentMethod}) {
        return Net::Braintree::Result->new(response => { success => 1 });
    }
    
    return Net::Braintree::Result->new(response => { success => 0 });
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
