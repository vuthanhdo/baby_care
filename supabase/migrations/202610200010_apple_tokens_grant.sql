-- Tables created through the management connector do not inherit the default grants; the apple-token
-- Edge Function (service role) must be able to read and write the token rows.
grant select, insert, update, delete on public.apple_tokens to service_role;
