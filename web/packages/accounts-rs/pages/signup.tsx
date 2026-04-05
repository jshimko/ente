import { AccountsPageContents } from "ente-accounts-rs/components/layouts/centered-paper";
import { SignUpContents } from "ente-accounts-rs/components/SignUpContents";
import { savedPartialLocalUser } from "ente-accounts-rs/services/accounts-db";
import { LoadingIndicator } from "ente-base/components/loaders";
import { customAPIHost } from "ente-base/origins";
import { isRegistrationDisabled } from "ente-base/server-config";
import { useRouter } from "next/router";
import React, { useCallback, useEffect, useState } from "react";

/**
 * A page that allows the user to signup for a new Ente account.
 *
 * See: [Note: Login pages]
 */
const Page: React.FC = () => {
    const [loading, setLoading] = useState(true);
    const [host, setHost] = useState<string | undefined>(undefined);

    const router = useRouter();

    useEffect(() => {
        void customAPIHost().then(setHost);
        if (savedPartialLocalUser()?.email) {
            void router.replace("/verify");
            return;
        }
        // See: [Note: Server-side registration gate]
        void isRegistrationDisabled().then((disabled) => {
            if (disabled) {
                void router.replace("/login");
            } else {
                setLoading(false);
            }
        });
    }, [router]);

    const onLogin = useCallback(() => void router.push("/login"), [router]);

    return loading ? (
        <LoadingIndicator />
    ) : (
        <AccountsPageContents>
            <SignUpContents {...{ router, host, onLogin }} />
        </AccountsPageContents>
    );
};

export default Page;
