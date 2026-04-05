import { publicRequestHeaders } from "ente-base/http";
import log from "ente-base/log";
import { apiOrigin } from "ente-base/origins";
import { z } from "zod";

const PingResponse = z.object({
    message: z.string(),
    registrationDisabled: z.boolean().optional(),
});

let _cachedResult: Promise<boolean> | undefined;

/**
 * Return `true` if the remote server has disabled new user registration.
 *
 * The result is fetched once from the `/ping` endpoint and then cached for the
 * lifetime of the page. If the fetch fails (e.g., old server that does not
 * include this field, or network error), this defaults to `false` (registration
 * assumed to be allowed).
 *
 * [Note: Server-side registration gate]
 *
 * The server enforces registration denial with a 403 regardless, so this is
 * purely a UX improvement to hide signup UI preemptively.
 */
export const isRegistrationDisabled = (): Promise<boolean> =>
    (_cachedResult ??= fetchRegistrationDisabled());

const fetchRegistrationDisabled = async (): Promise<boolean> => {
    try {
        const origin = await apiOrigin();
        const res = await fetch(`${origin}/ping`, {
            headers: publicRequestHeaders(),
        });
        if (!res.ok) return false;
        const data = PingResponse.parse(await res.json());
        return data.registrationDisabled ?? false;
    } catch (e) {
        log.warn("Failed to fetch server config from /ping", e);
        return false;
    }
};

/**
 * Reset the cached registration-disabled state.
 *
 * This should be called when the user changes the custom API origin (via
 * DevSettings), so that the next call to {@link isRegistrationDisabled}
 * re-fetches from the new server.
 */
export const resetRegistrationDisabledCache = () => {
    _cachedResult = undefined;
};
