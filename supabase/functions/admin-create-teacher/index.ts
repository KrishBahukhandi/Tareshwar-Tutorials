import { createClient } from 'jsr:@supabase/supabase-js@2'
import nodemailer from 'npm:nodemailer'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function isValidEmail(email: string) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = request.headers.get('Authorization')
    if (!authorization) {
      return jsonResponse(401, { error: 'Missing authorization header.' })
    }

    const { name, email, password } = await request.json()

    if (typeof name !== 'string' || name.trim().length < 3) {
      return jsonResponse(400, { error: 'Teacher name must be at least 3 characters.' })
    }
    if (typeof email !== 'string' || !isValidEmail(email.trim().toLowerCase())) {
      return jsonResponse(400, { error: 'Please enter a valid teacher email address.' })
    }
    if (typeof password !== 'string' || password.length < 8) {
      return jsonResponse(400, { error: 'Temporary password must be at least 8 characters.' })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const smtpHost = Deno.env.get('SMTP_HOST') ?? 'smtp.gmail.com'
    const smtpPort = Number(Deno.env.get('SMTP_PORT') ?? '465')
    const smtpUser = Deno.env.get('SMTP_USER') ?? ''
    const smtpPass = Deno.env.get('SMTP_PASS') ?? ''
    const smtpAdminEmail = Deno.env.get('SMTP_ADMIN_EMAIL') ?? ''
    const senderName = Deno.env.get('SMTP_SENDER_NAME') ?? 'Tareshwar Tutorials'
    const appUrl = Deno.env.get('PUBLIC_APP_URL') ?? Deno.env.get('AUTH_REDIRECT_URL') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(500, { error: 'Supabase environment variables are not configured for this function.' })
    }

    if (!smtpUser || !smtpPass || !smtpAdminEmail) {
      return jsonResponse(500, { error: 'SMTP settings are not configured for teacher invite emails.' })
    }

    const token = authorization.replace(/^Bearer\s+/i, '').trim()
    if (!token) {
      return jsonResponse(401, { error: 'Missing bearer token.' })
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    const {
      data: { user: actor },
      error: actorError,
    } = await serviceClient.auth.getUser(token)

    if (actorError || !actor) {
      return jsonResponse(401, { error: 'Admin session could not be verified.' })
    }

    const { data: actorProfile, error: actorProfileError } = await serviceClient
      .from('users')
      .select('role, name, email')
      .eq('id', actor.id)
      .maybeSingle()

    if (actorProfileError || actorProfile?.role !== 'admin') {
      return jsonResponse(403, { error: 'Only admins can create teacher accounts.' })
    }

    const normalizedEmail = email.trim().toLowerCase()
    const trimmedName = name.trim()

    const { data: existingUser } = await serviceClient
      .from('users')
      .select('id')
      .eq('email', normalizedEmail)
      .maybeSingle()

    if (existingUser != null) {
      return jsonResponse(409, { error: 'A user with this email already exists.' })
    }

    const { data: createdUserData, error: createError } = await serviceClient.auth.admin.createUser({
      email: normalizedEmail,
      password,
      email_confirm: true,
      user_metadata: {
        name: trimmedName,
        role: 'teacher',
      },
      app_metadata: {
        role: 'teacher',
      },
    })

    if (createError || !createdUserData.user) {
      return jsonResponse(400, {
        error: createError?.message ?? 'Could not create the teacher account.',
      })
    }

    const teacherUser = createdUserData.user

    const { error: profileError } = await serviceClient.from('users').upsert({
      id: teacherUser.id,
      name: trimmedName,
      email: normalizedEmail,
      role: 'teacher',
      is_active: true,
    })

    if (profileError) {
      await serviceClient.auth.admin.deleteUser(teacherUser.id)
      return jsonResponse(500, { error: 'Teacher profile could not be saved.' })
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort == 465,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    })

    const loginHint = appUrl
      ? `Open ${appUrl} and sign in with the credentials below.`
      : 'Open the app and sign in with the credentials below.'

    try {
      await transporter.sendMail({
        from: `"${senderName}" <${smtpAdminEmail}>`,
        to: normalizedEmail,
        subject: 'Your Teacher Account Has Been Created',
        text: [
          `Hello ${trimmedName},`,
          '',
          'Your teacher account has been created for Tareshwar Tutorials.',
          '',
          `Email: ${normalizedEmail}`,
          `Temporary password: ${password}`,
          '',
          loginHint,
          'After your first login, you can use the "Forgot Password" option anytime to reset your password.',
          '',
          `Created by: ${actorProfile?.name ?? actorProfile?.email ?? 'Institute Admin'}`,
        ].join('\n'),
        html: `
          <div style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.6;">
            <h2 style="margin-bottom: 8px;">Your Teacher Account Is Ready</h2>
            <p>Hello ${trimmedName},</p>
            <p>Your teacher account has been created for <strong>Tareshwar Tutorials</strong>.</p>
            <p><strong>Email:</strong> ${normalizedEmail}<br /><strong>Temporary password:</strong> ${password}</p>
            <p>${loginHint}</p>
            <p>After your first login, you can use the <strong>Forgot Password</strong> option anytime to reset your password.</p>
            <p style="margin-top: 24px;">Created by: ${actorProfile?.name ?? actorProfile?.email ?? 'Institute Admin'}</p>
          </div>
        `,
      })
    } catch (_emailError) {
      await serviceClient.from('users').delete().eq('id', teacherUser.id)
      await serviceClient.auth.admin.deleteUser(teacherUser.id)
      return jsonResponse(500, {
        error: 'Teacher account email could not be sent. No account was created.',
      })
    }

    await serviceClient.from('audit_logs').insert({
      actor_id: actor.id,
      action: 'teacher.created',
      entity_type: 'user',
      entity_id: teacherUser.id,
      details: {
        role: 'teacher',
        email: normalizedEmail,
      },
    })

    return jsonResponse(200, {
      user_id: teacherUser.id,
      email: normalizedEmail,
    })
  } catch (_error) {
    return jsonResponse(500, {
      error: 'Unexpected error while creating the teacher account.',
    })
  }
})
