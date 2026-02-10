import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Verify the user's JWT
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userId = user.id;

    // Admin client for privileged operations (bypasses RLS)
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Delete in foreign-key order: completed_dates → habits → profiles → auth user

    // 1. Get all habit IDs for this user
    const { data: habits, error: habitsQueryError } = await adminClient
      .from("habits")
      .select("id")
      .eq("user_id", userId);

    if (habitsQueryError) {
      throw new Error(`Failed to query habits: ${habitsQueryError.message}`);
    }

    // 2. Delete completed_dates for all user's habits
    if (habits && habits.length > 0) {
      const habitIds = habits.map((h: { id: string }) => h.id);
      const { error: completedDatesError } = await adminClient
        .from("completed_dates")
        .delete()
        .in("habit_id", habitIds);

      if (completedDatesError) {
        throw new Error(
          `Failed to delete completed dates: ${completedDatesError.message}`
        );
      }
    }

    // 3. Delete all habits for this user
    const { error: habitsDeleteError } = await adminClient
      .from("habits")
      .delete()
      .eq("user_id", userId);

    if (habitsDeleteError) {
      throw new Error(`Failed to delete habits: ${habitsDeleteError.message}`);
    }

    // 4. Delete the user's profile
    const { error: profileError } = await adminClient
      .from("profiles")
      .delete()
      .eq("id", userId);

    if (profileError) {
      throw new Error(`Failed to delete profile: ${profileError.message}`);
    }

    // 5. Delete the auth user
    const { error: authDeleteError } =
      await adminClient.auth.admin.deleteUser(userId);

    if (authDeleteError) {
      throw new Error(
        `Failed to delete auth user: ${authDeleteError.message}`
      );
    }

    return new Response(
      JSON.stringify({ message: "Account deleted successfully" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
