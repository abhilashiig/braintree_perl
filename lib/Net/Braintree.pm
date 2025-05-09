package Net::Braintree;

use 5.006;
use strict;
use warnings;
use Net::Braintree::Address;
use Net::Braintree::AdvancedSearchFields;
use Net::Braintree::AdvancedSearchNodes;
use Net::Braintree::ApplePayCard;
use Net::Braintree::ClientToken;
use Net::Braintree::CreditCard;
use Net::Braintree::Customer;
use Net::Braintree::CustomerSearch;
use Net::Braintree::DisbursementDetails;
use Net::Braintree::Dispute;
use Net::Braintree::MerchantAccount;
use Net::Braintree::PartnerMerchant;
use Net::Braintree::PaymentMethod;
use Net::Braintree::PayPalAccount;
use Net::Braintree::PayPalDetails;
use Net::Braintree::ResourceCollection;
use Net::Braintree::SettlementBatchSummary;
use Net::Braintree::Subscription;
use Net::Braintree::SubscriptionSearch;
use Net::Braintree::Transaction;
use Net::Braintree::TransactionSearch;
use Net::Braintree::Disbursement;
use Net::Braintree::TransparentRedirect;
use Net::Braintree::WebhookNotification;
use Net::Braintree::WebhookTesting;
use Net::Braintree::Configuration;
use Net::Braintree::GraphQL;
use Net::Braintree::GraphQLGateway;

=head1 NAME

Net::Braintree - A modern GraphQL-only client library for the Braintree Payment Services Gateway API

=head1 VERSION

Version 2.0.0

=head1 NOTICE

This is a community-maintained fork of the original Braintree Perl SDK that has been completely rewritten to use only the modern GraphQL APIs.
This is NOT an official Braintree SDK and is not maintained by Braintree or PayPal.

The legacy REST APIs have been completely removed from this version. This SDK uses exclusively the modern GraphQL APIs
for all operations, providing better performance, more detailed responses, and access to the latest Braintree features.

=cut

our $VERSION = '2.0.0';

my $configuration_instance = Net::Braintree::Configuration->new;

sub configuration { return $configuration_instance; }

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Braintree


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Braintree>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Braintree>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Braintree>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Braintree/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011-2017 Braintree, a division of PayPal, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::Braintree
