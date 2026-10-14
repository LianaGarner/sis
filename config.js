// Fill in both projects. The anon keys are designed to be public (never use the service_role key).
const PROD={url:'https://mmnkmmcopuklxvnkgfhe.supabase.co',key:'sb_publishable_SmrOty5MVqkjQibPPtOpMA_GztMWlZ4'};
const TEST={url:'https://mmnkmmcopuklxvnkgfhe.supabase.co',key:'sb_publishable_SmrOty5MVqkjQibPPtOpMA_GztMWlZ4'};
// Opening the site on your own computer (Live Server) uses TEST; the GitHub site uses PROD.
const isLocal=['localhost','127.0.0.1'].includes(location.hostname);
const SUPABASE_URL=(isLocal?TEST:PROD).url,SUPABASE_KEY=(isLocal?TEST:PROD).key;
const SCHOOL='Flowers for the Future International';
