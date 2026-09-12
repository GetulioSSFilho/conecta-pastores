-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'INVITED', 'SUSPENDED', 'DISABLED');

-- CreateEnum
CREATE TYPE "PastorStatus" AS ENUM ('ACTIVE', 'IN_TRAINING', 'ON_LEAVE', 'SUSPENDED', 'MISSIONARY', 'DISMISSED', 'DECEASED');

-- CreateEnum
CREATE TYPE "MaritalStatus" AS ENUM ('SINGLE', 'MARRIED', 'WIDOWED', 'DIVORCED', 'OTHER');

-- CreateEnum
CREATE TYPE "ChurchStatus" AS ENUM ('ACTIVE', 'PLANTING', 'INACTIVE', 'CLOSED');

-- CreateEnum
CREATE TYPE "ChurchType" AS ENUM ('MAIN', 'CAMPUS', 'CONGREGATION', 'MISSION_POINT');

-- CreateEnum
CREATE TYPE "RelationshipType" AS ENUM ('SUPERVISION', 'MENTORSHIP', 'INTERIM');

-- CreateEnum
CREATE TYPE "CareStatus" AS ENUM ('PLANNED', 'DONE', 'CANCELED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "Confidentiality" AS ENUM ('NORMAL', 'RESTRICTED', 'CONFIDENTIAL');

-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'WAITING', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "RequestPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "PostType" AS ENUM ('ANNOUNCEMENT', 'NEWS', 'DEVOTIONAL', 'VIDEO', 'DOCUMENT', 'EVENT', 'URGENT');

-- CreateEnum
CREATE TYPE "PostStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "AudienceType" AS ENUM ('ALL', 'COUNTRY', 'REGION', 'CHURCH', 'MINISTRY_ROLE', 'GROUP', 'USER', 'SUBTREE');

-- CreateEnum
CREATE TYPE "DocumentCategory" AS ENUM ('PASTORAL_DOCUMENT', 'CERTIFICATE', 'MINISTERIAL_DOCUMENT', 'AUTHORIZATION', 'IDENTIFICATION', 'OTHER');

-- CreateEnum
CREATE TYPE "DocumentVisibility" AS ENUM ('OWNER_ONLY', 'SUPERVISION_CHAIN', 'ADMIN_ONLY', 'SCOPED');

-- CreateEnum
CREATE TYPE "CredentialType" AS ENUM ('ORDINATION', 'MINISTERIAL', 'MISSIONARY', 'TEMPORARY', 'OTHER');

-- CreateEnum
CREATE TYPE "CredentialStatus" AS ENUM ('ACTIVE', 'EXPIRED', 'REVOKED', 'PENDING');

-- CreateEnum
CREATE TYPE "TrainingKind" AS ENUM ('COURSE', 'TRAINING', 'TRACK', 'WORKSHOP');

-- CreateEnum
CREATE TYPE "TrainingStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "EnrollmentStatus" AS ENUM ('ENROLLED', 'IN_PROGRESS', 'COMPLETED', 'DROPPED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "EventType" AS ENUM ('CARE_MEETING', 'MEETING', 'VISIT', 'COURSE', 'TRAINING', 'CONGRESS', 'SERVICE', 'CONFERENCE', 'TRIP', 'MISSION', 'OTHER');

-- CreateEnum
CREATE TYPE "EventScopeType" AS ENUM ('INDIVIDUAL', 'CHURCH', 'REGION', 'COUNTRY', 'GLOBAL');

-- CreateEnum
CREATE TYPE "EventParticipantStatus" AS ENUM ('INVITED', 'ACCEPTED', 'DECLINED', 'TENTATIVE', 'ATTENDED', 'ABSENT');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('CHANNEL_POST', 'PASTORAL_CARE', 'REQUEST', 'EVENT', 'DOCUMENT', 'TRAINING', 'SYSTEM');

-- CreateEnum
CREATE TYPE "DevicePlatform" AS ENUM ('ANDROID', 'IOS', 'WEB');

-- CreateEnum
CREATE TYPE "ScopeType" AS ENUM ('GLOBAL', 'COUNTRY', 'REGION', 'CHURCH', 'SUBTREE', 'SELF');

-- CreateEnum
CREATE TYPE "AuditAction" AS ENUM ('LOGIN', 'LOGIN_FAILED', 'LOGOUT', 'TOKEN_REFRESH', 'PASSWORD_CHANGE', 'PASSWORD_RESET_REQUEST', 'PASSWORD_RESET', 'CREATE', 'UPDATE', 'DELETE', 'RESTORE', 'READ_CONFIDENTIAL', 'PERMISSION_CHANGE', 'ROLE_CHANGE', 'SUPERVISOR_CHANGE', 'EXPORT', 'ACCESS_DENIED');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'INVITED',
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "avatar_url" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'pt-BR',
    "timezone" TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    "phone_e164" TEXT,
    "must_change_password" BOOLEAN NOT NULL DEFAULT false,
    "last_login_at" TIMESTAMPTZ,
    "failed_login_count" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "user_agent" TEXT,
    "ip" TEXT,
    "device_name" TEXT,
    "platform" "DevicePlatform",
    "expires_at" TIMESTAMPTZ NOT NULL,
    "revoked_at" TIMESTAMPTZ,
    "revoked_reason" TEXT,
    "replaced_by_id" UUID,
    "last_used_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "password_reset_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "used_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "is_system" BOOLEAN NOT NULL DEFAULT false,
    "rank" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "permissions" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "resource" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "role_id" UUID NOT NULL,
    "permission_id" UUID NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("role_id","permission_id")
);

-- CreateTable
CREATE TABLE "user_roles" (
    "user_id" UUID NOT NULL,
    "role_id" UUID NOT NULL,
    "granted_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "granted_by" UUID,

    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id","role_id")
);

-- CreateTable
CREATE TABLE "user_scopes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "ScopeType" NOT NULL,
    "ref_id" UUID,
    "permission_keys" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "granted_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "granted_by" UUID,
    "expires_at" TIMESTAMPTZ,

    CONSTRAINT "user_scopes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "countries" (
    "id" UUID NOT NULL,
    "code" CHAR(2) NOT NULL,
    "code3" CHAR(3) NOT NULL,
    "name" TEXT NOT NULL,
    "native_name" TEXT,
    "phone_code" TEXT NOT NULL,
    "currency" CHAR(3),
    "default_locale" TEXT NOT NULL DEFAULT 'pt-BR',
    "default_timezone" TEXT NOT NULL DEFAULT 'UTC',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "countries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "regions" (
    "id" UUID NOT NULL,
    "country_id" UUID NOT NULL,
    "parent_id" UUID,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "level" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "regions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "churches" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "ChurchType" NOT NULL DEFAULT 'MAIN',
    "status" "ChurchStatus" NOT NULL DEFAULT 'ACTIVE',
    "parent_id" UUID,
    "country_id" UUID NOT NULL,
    "region_id" UUID,
    "city" TEXT NOT NULL,
    "address" TEXT,
    "postal_code" TEXT,
    "latitude" DECIMAL(10,7),
    "longitude" DECIMAL(10,7),
    "phone_e164" TEXT,
    "email" TEXT,
    "timezone" TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    "founded_at" DATE,
    "lead_pastor_id" UUID,
    "members_estimate" INTEGER,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "churches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ministry_roles" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "rank" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "ministry_roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pastors" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "pastoral_name" TEXT NOT NULL,
    "photo_url" TEXT,
    "email" TEXT,
    "phone_e164" TEXT,
    "whatsapp_e164" TEXT,
    "birth_date" DATE,
    "marital_status" "MaritalStatus",
    "spouse_name" TEXT,
    "spouse_birth_date" DATE,
    "country_id" UUID NOT NULL,
    "region_id" UUID,
    "city" TEXT,
    "address" TEXT,
    "postal_code" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'pt-BR',
    "timezone" TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    "church_id" UUID,
    "ministry_role_id" UUID,
    "ministry_title" TEXT,
    "joined_at" DATE,
    "ordained_at" DATE,
    "status" "PastorStatus" NOT NULL DEFAULT 'ACTIVE',
    "biography" TEXT,
    "admin_notes" TEXT,
    "last_care_at" TIMESTAMPTZ,
    "next_care_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "pastors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pastoral_relationships" (
    "id" UUID NOT NULL,
    "supervisor_id" UUID NOT NULL,
    "subordinate_id" UUID NOT NULL,
    "type" "RelationshipType" NOT NULL DEFAULT 'SUPERVISION',
    "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "created_by" UUID,

    CONSTRAINT "pastoral_relationships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pastoral_closure" (
    "ancestor_id" UUID NOT NULL,
    "descendant_id" UUID NOT NULL,
    "depth" INTEGER NOT NULL,

    CONSTRAINT "pastoral_closure_pkey" PRIMARY KEY ("ancestor_id","descendant_id")
);

-- CreateTable
CREATE TABLE "pastoral_care_types" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "icon" TEXT,
    "color" TEXT,
    "rank" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pastoral_care_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pastoral_cares" (
    "id" UUID NOT NULL,
    "pastor_id" UUID NOT NULL,
    "performed_by_id" UUID NOT NULL,
    "type_id" UUID NOT NULL,
    "occurred_at" TIMESTAMPTZ NOT NULL,
    "status" "CareStatus" NOT NULL DEFAULT 'DONE',
    "summary" TEXT NOT NULL,
    "notes" TEXT,
    "next_action" TEXT,
    "next_care_at" TIMESTAMPTZ,
    "confidentiality" "Confidentiality" NOT NULL DEFAULT 'NORMAL',
    "duration_minutes" INTEGER,
    "location" TEXT,
    "created_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "pastoral_cares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "request_categories" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "icon" TEXT,
    "sla_hours" INTEGER,
    "rank" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "request_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "requests" (
    "id" UUID NOT NULL,
    "number" SERIAL NOT NULL,
    "category_id" UUID NOT NULL,
    "requester_id" UUID NOT NULL,
    "pastor_id" UUID,
    "assignee_id" UUID,
    "subject" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'OPEN',
    "priority" "RequestPriority" NOT NULL DEFAULT 'NORMAL',
    "confidentiality" "Confidentiality" NOT NULL DEFAULT 'NORMAL',
    "due_at" TIMESTAMPTZ,
    "resolved_at" TIMESTAMPTZ,
    "closed_at" TIMESTAMPTZ,
    "resolution" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "request_timeline_entries" (
    "id" UUID NOT NULL,
    "request_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "message" TEXT,
    "metadata" JSONB,
    "is_internal" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "request_timeline_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "channel_posts" (
    "id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "type" "PostType" NOT NULL DEFAULT 'ANNOUNCEMENT',
    "status" "PostStatus" NOT NULL DEFAULT 'DRAFT',
    "title" TEXT NOT NULL,
    "summary" TEXT,
    "content" TEXT NOT NULL,
    "cover_url" TEXT,
    "video_url" TEXT,
    "is_pinned" BOOLEAN NOT NULL DEFAULT false,
    "requires_ack" BOOLEAN NOT NULL DEFAULT false,
    "allowed_comments" BOOLEAN NOT NULL DEFAULT false,
    "published_at" TIMESTAMPTZ,
    "expires_at" TIMESTAMPTZ,
    "audience_count" INTEGER NOT NULL DEFAULT 0,
    "read_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "channel_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "channel_post_audiences" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "type" "AudienceType" NOT NULL,
    "ref_id" UUID,

    CONSTRAINT "channel_post_audiences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "post_reads" (
    "post_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "read_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acknowledged_at" TIMESTAMPTZ,

    CONSTRAINT "post_reads_pkey" PRIMARY KEY ("post_id","user_id")
);

-- CreateTable
CREATE TABLE "documents" (
    "id" UUID NOT NULL,
    "category" "DocumentCategory" NOT NULL DEFAULT 'OTHER',
    "title" TEXT NOT NULL,
    "description" TEXT,
    "storage_key" TEXT NOT NULL,
    "storage_bucket" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "size_bytes" BIGINT NOT NULL,
    "checksum" TEXT,
    "visibility" "DocumentVisibility" NOT NULL DEFAULT 'SUPERVISION_CHAIN',
    "confidentiality" "Confidentiality" NOT NULL DEFAULT 'NORMAL',
    "issued_at" DATE,
    "expires_at" DATE,
    "pastor_id" UUID,
    "uploaded_by_id" UUID NOT NULL,
    "post_id" UUID,
    "request_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "credentials" (
    "id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "pastor_id" UUID NOT NULL,
    "type" "CredentialType" NOT NULL DEFAULT 'MINISTERIAL',
    "status" "CredentialStatus" NOT NULL DEFAULT 'PENDING',
    "issued_at" DATE NOT NULL,
    "expires_at" DATE,
    "revoked_at" TIMESTAMPTZ,
    "revoked_reason" TEXT,
    "verification_token" TEXT NOT NULL,
    "issued_by_id" UUID,
    "document_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "credentials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trainings" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "kind" "TrainingKind" NOT NULL DEFAULT 'COURSE',
    "status" "TrainingStatus" NOT NULL DEFAULT 'DRAFT',
    "title" TEXT NOT NULL,
    "summary" TEXT,
    "description" TEXT,
    "cover_url" TEXT,
    "workload_minutes" INTEGER,
    "is_mandatory" BOOLEAN NOT NULL DEFAULT false,
    "passing_score" INTEGER NOT NULL DEFAULT 100,
    "language" TEXT NOT NULL DEFAULT 'pt-BR',
    "available_from" TIMESTAMPTZ,
    "available_to" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "trainings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "training_modules" (
    "id" UUID NOT NULL,
    "training_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "content_type" TEXT NOT NULL,
    "content_url" TEXT,
    "content_body" TEXT,
    "duration_minutes" INTEGER,
    "position" INTEGER NOT NULL,
    "is_required" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "training_modules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "training_enrollments" (
    "id" UUID NOT NULL,
    "training_id" UUID NOT NULL,
    "pastor_id" UUID NOT NULL,
    "status" "EnrollmentStatus" NOT NULL DEFAULT 'ENROLLED',
    "enrolled_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "started_at" TIMESTAMPTZ,
    "completed_at" TIMESTAMPTZ,
    "due_at" TIMESTAMPTZ,
    "progress_pct" INTEGER NOT NULL DEFAULT 0,
    "score" INTEGER,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "training_enrollments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "training_progress" (
    "id" UUID NOT NULL,
    "enrollment_id" UUID NOT NULL,
    "module_id" UUID NOT NULL,
    "completed" BOOLEAN NOT NULL DEFAULT false,
    "completed_at" TIMESTAMPTZ,
    "seconds_spent" INTEGER NOT NULL DEFAULT 0,
    "last_position_sec" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "training_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "certificates" (
    "id" UUID NOT NULL,
    "enrollment_id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "issued_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verification_token" TEXT NOT NULL,
    "storage_key" TEXT,

    CONSTRAINT "certificates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "type" "EventType" NOT NULL DEFAULT 'MEETING',
    "scope" "EventScopeType" NOT NULL DEFAULT 'INDIVIDUAL',
    "scope_ref_id" UUID,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "location" TEXT,
    "is_online" BOOLEAN NOT NULL DEFAULT false,
    "meeting_url" TEXT,
    "starts_at" TIMESTAMPTZ NOT NULL,
    "ends_at" TIMESTAMPTZ NOT NULL,
    "all_day" BOOLEAN NOT NULL DEFAULT false,
    "timezone" TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    "church_id" UUID,
    "organizer_id" UUID NOT NULL,
    "recurrence_rule" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_participants" (
    "id" UUID NOT NULL,
    "event_id" UUID NOT NULL,
    "user_id" UUID,
    "pastor_id" UUID,
    "status" "EventParticipantStatus" NOT NULL DEFAULT 'INVITED',
    "is_required" BOOLEAN NOT NULL DEFAULT true,
    "responded_at" TIMESTAMPTZ,

    CONSTRAINT "event_participants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "link" TEXT,
    "entity" TEXT,
    "entity_id" UUID,
    "data" JSONB,
    "read_at" TIMESTAMPTZ,
    "sent_at" TIMESTAMPTZ,
    "push_sent" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_devices" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "platform" "DevicePlatform" NOT NULL,
    "token" TEXT NOT NULL,
    "device_name" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'pt-BR',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "last_seen_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "action" "AuditAction" NOT NULL,
    "entity" TEXT,
    "entity_id" UUID,
    "metadata" JSONB,
    "ip" TEXT,
    "user_agent" TEXT,
    "request_id" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_status_idx" ON "users"("status");

-- CreateIndex
CREATE INDEX "users_deleted_at_idx" ON "users"("deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_token_hash_key" ON "sessions"("token_hash");

-- CreateIndex
CREATE INDEX "sessions_user_id_revoked_at_idx" ON "sessions"("user_id", "revoked_at");

-- CreateIndex
CREATE INDEX "sessions_expires_at_idx" ON "sessions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "password_reset_tokens_token_hash_key" ON "password_reset_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "password_reset_tokens_user_id_idx" ON "password_reset_tokens"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "roles_key_key" ON "roles"("key");

-- CreateIndex
CREATE UNIQUE INDEX "permissions_key_key" ON "permissions"("key");

-- CreateIndex
CREATE INDEX "permissions_resource_idx" ON "permissions"("resource");

-- CreateIndex
CREATE UNIQUE INDEX "permissions_resource_action_key" ON "permissions"("resource", "action");

-- CreateIndex
CREATE INDEX "user_roles_role_id_idx" ON "user_roles"("role_id");

-- CreateIndex
CREATE INDEX "user_scopes_user_id_idx" ON "user_scopes"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_scopes_user_id_type_ref_id_key" ON "user_scopes"("user_id", "type", "ref_id");

-- CreateIndex
CREATE UNIQUE INDEX "countries_code_key" ON "countries"("code");

-- CreateIndex
CREATE UNIQUE INDEX "countries_code3_key" ON "countries"("code3");

-- CreateIndex
CREATE INDEX "countries_is_active_idx" ON "countries"("is_active");

-- CreateIndex
CREATE INDEX "regions_country_id_idx" ON "regions"("country_id");

-- CreateIndex
CREATE INDEX "regions_parent_id_idx" ON "regions"("parent_id");

-- CreateIndex
CREATE UNIQUE INDEX "regions_country_id_code_key" ON "regions"("country_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "churches_code_key" ON "churches"("code");

-- CreateIndex
CREATE UNIQUE INDEX "churches_lead_pastor_id_key" ON "churches"("lead_pastor_id");

-- CreateIndex
CREATE INDEX "churches_country_id_region_id_idx" ON "churches"("country_id", "region_id");

-- CreateIndex
CREATE INDEX "churches_status_idx" ON "churches"("status");

-- CreateIndex
CREATE INDEX "churches_parent_id_idx" ON "churches"("parent_id");

-- CreateIndex
CREATE INDEX "churches_deleted_at_idx" ON "churches"("deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "ministry_roles_key_key" ON "ministry_roles"("key");

-- CreateIndex
CREATE UNIQUE INDEX "pastors_user_id_key" ON "pastors"("user_id");

-- CreateIndex
CREATE INDEX "pastors_country_id_region_id_idx" ON "pastors"("country_id", "region_id");

-- CreateIndex
CREATE INDEX "pastors_church_id_idx" ON "pastors"("church_id");

-- CreateIndex
CREATE INDEX "pastors_status_idx" ON "pastors"("status");

-- CreateIndex
CREATE INDEX "pastors_deleted_at_idx" ON "pastors"("deleted_at");

-- CreateIndex
CREATE INDEX "pastors_last_care_at_idx" ON "pastors"("last_care_at");

-- CreateIndex
CREATE INDEX "pastoral_relationships_supervisor_id_is_active_idx" ON "pastoral_relationships"("supervisor_id", "is_active");

-- CreateIndex
CREATE INDEX "pastoral_relationships_subordinate_id_is_active_idx" ON "pastoral_relationships"("subordinate_id", "is_active");

-- CreateIndex
CREATE INDEX "pastoral_closure_descendant_id_idx" ON "pastoral_closure"("descendant_id");

-- CreateIndex
CREATE INDEX "pastoral_closure_ancestor_id_depth_idx" ON "pastoral_closure"("ancestor_id", "depth");

-- CreateIndex
CREATE UNIQUE INDEX "pastoral_care_types_key_key" ON "pastoral_care_types"("key");

-- CreateIndex
CREATE INDEX "pastoral_cares_pastor_id_occurred_at_idx" ON "pastoral_cares"("pastor_id", "occurred_at" DESC);

-- CreateIndex
CREATE INDEX "pastoral_cares_performed_by_id_occurred_at_idx" ON "pastoral_cares"("performed_by_id", "occurred_at" DESC);

-- CreateIndex
CREATE INDEX "pastoral_cares_next_care_at_idx" ON "pastoral_cares"("next_care_at");

-- CreateIndex
CREATE INDEX "pastoral_cares_confidentiality_idx" ON "pastoral_cares"("confidentiality");

-- CreateIndex
CREATE INDEX "pastoral_cares_deleted_at_idx" ON "pastoral_cares"("deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "request_categories_key_key" ON "request_categories"("key");

-- CreateIndex
CREATE UNIQUE INDEX "requests_number_key" ON "requests"("number");

-- CreateIndex
CREATE INDEX "requests_status_created_at_idx" ON "requests"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "requests_requester_id_idx" ON "requests"("requester_id");

-- CreateIndex
CREATE INDEX "requests_assignee_id_status_idx" ON "requests"("assignee_id", "status");

-- CreateIndex
CREATE INDEX "requests_pastor_id_idx" ON "requests"("pastor_id");

-- CreateIndex
CREATE INDEX "requests_deleted_at_idx" ON "requests"("deleted_at");

-- CreateIndex
CREATE INDEX "request_timeline_entries_request_id_created_at_idx" ON "request_timeline_entries"("request_id", "created_at");

-- CreateIndex
CREATE INDEX "channel_posts_status_published_at_idx" ON "channel_posts"("status", "published_at" DESC);

-- CreateIndex
CREATE INDEX "channel_posts_type_idx" ON "channel_posts"("type");

-- CreateIndex
CREATE INDEX "channel_posts_deleted_at_idx" ON "channel_posts"("deleted_at");

-- CreateIndex
CREATE INDEX "channel_post_audiences_type_ref_id_idx" ON "channel_post_audiences"("type", "ref_id");

-- CreateIndex
CREATE UNIQUE INDEX "channel_post_audiences_post_id_type_ref_id_key" ON "channel_post_audiences"("post_id", "type", "ref_id");

-- CreateIndex
CREATE INDEX "post_reads_user_id_read_at_idx" ON "post_reads"("user_id", "read_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "documents_storage_key_key" ON "documents"("storage_key");

-- CreateIndex
CREATE INDEX "documents_pastor_id_idx" ON "documents"("pastor_id");

-- CreateIndex
CREATE INDEX "documents_category_idx" ON "documents"("category");

-- CreateIndex
CREATE INDEX "documents_expires_at_idx" ON "documents"("expires_at");

-- CreateIndex
CREATE INDEX "documents_deleted_at_idx" ON "documents"("deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "credentials_number_key" ON "credentials"("number");

-- CreateIndex
CREATE UNIQUE INDEX "credentials_verification_token_key" ON "credentials"("verification_token");

-- CreateIndex
CREATE UNIQUE INDEX "credentials_document_id_key" ON "credentials"("document_id");

-- CreateIndex
CREATE INDEX "credentials_pastor_id_status_idx" ON "credentials"("pastor_id", "status");

-- CreateIndex
CREATE INDEX "credentials_expires_at_idx" ON "credentials"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "trainings_code_key" ON "trainings"("code");

-- CreateIndex
CREATE INDEX "trainings_status_idx" ON "trainings"("status");

-- CreateIndex
CREATE INDEX "training_modules_training_id_idx" ON "training_modules"("training_id");

-- CreateIndex
CREATE UNIQUE INDEX "training_modules_training_id_position_key" ON "training_modules"("training_id", "position");

-- CreateIndex
CREATE INDEX "training_enrollments_pastor_id_status_idx" ON "training_enrollments"("pastor_id", "status");

-- CreateIndex
CREATE INDEX "training_enrollments_due_at_idx" ON "training_enrollments"("due_at");

-- CreateIndex
CREATE UNIQUE INDEX "training_enrollments_training_id_pastor_id_key" ON "training_enrollments"("training_id", "pastor_id");

-- CreateIndex
CREATE UNIQUE INDEX "training_progress_enrollment_id_module_id_key" ON "training_progress"("enrollment_id", "module_id");

-- CreateIndex
CREATE UNIQUE INDEX "certificates_enrollment_id_key" ON "certificates"("enrollment_id");

-- CreateIndex
CREATE UNIQUE INDEX "certificates_number_key" ON "certificates"("number");

-- CreateIndex
CREATE UNIQUE INDEX "certificates_verification_token_key" ON "certificates"("verification_token");

-- CreateIndex
CREATE INDEX "events_starts_at_idx" ON "events"("starts_at");

-- CreateIndex
CREATE INDEX "events_scope_scope_ref_id_idx" ON "events"("scope", "scope_ref_id");

-- CreateIndex
CREATE INDEX "events_church_id_idx" ON "events"("church_id");

-- CreateIndex
CREATE INDEX "events_deleted_at_idx" ON "events"("deleted_at");

-- CreateIndex
CREATE INDEX "event_participants_user_id_status_idx" ON "event_participants"("user_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "event_participants_event_id_user_id_key" ON "event_participants"("event_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "event_participants_event_id_pastor_id_key" ON "event_participants"("event_id", "pastor_id");

-- CreateIndex
CREATE INDEX "notifications_user_id_read_at_created_at_idx" ON "notifications"("user_id", "read_at", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "notification_devices_token_key" ON "notification_devices"("token");

-- CreateIndex
CREATE INDEX "notification_devices_user_id_is_active_idx" ON "notification_devices"("user_id", "is_active");

-- CreateIndex
CREATE INDEX "audit_logs_user_id_created_at_idx" ON "audit_logs"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_entity_entity_id_idx" ON "audit_logs"("entity", "entity_id");

-- CreateIndex
CREATE INDEX "audit_logs_action_created_at_idx" ON "audit_logs"("action", "created_at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_created_at_idx" ON "audit_logs"("created_at" DESC);

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "password_reset_tokens" ADD CONSTRAINT "password_reset_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permission_id_fkey" FOREIGN KEY ("permission_id") REFERENCES "permissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_scopes" ADD CONSTRAINT "user_scopes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "regions" ADD CONSTRAINT "regions_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "countries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "regions" ADD CONSTRAINT "regions_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "regions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "churches" ADD CONSTRAINT "churches_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "countries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "churches" ADD CONSTRAINT "churches_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "regions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "churches" ADD CONSTRAINT "churches_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "churches" ADD CONSTRAINT "churches_lead_pastor_id_fkey" FOREIGN KEY ("lead_pastor_id") REFERENCES "pastors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastors" ADD CONSTRAINT "pastors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastors" ADD CONSTRAINT "pastors_country_id_fkey" FOREIGN KEY ("country_id") REFERENCES "countries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastors" ADD CONSTRAINT "pastors_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "regions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastors" ADD CONSTRAINT "pastors_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastors" ADD CONSTRAINT "pastors_ministry_role_id_fkey" FOREIGN KEY ("ministry_role_id") REFERENCES "ministry_roles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_relationships" ADD CONSTRAINT "pastoral_relationships_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_relationships" ADD CONSTRAINT "pastoral_relationships_subordinate_id_fkey" FOREIGN KEY ("subordinate_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_closure" ADD CONSTRAINT "pastoral_closure_ancestor_id_fkey" FOREIGN KEY ("ancestor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_closure" ADD CONSTRAINT "pastoral_closure_descendant_id_fkey" FOREIGN KEY ("descendant_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_cares" ADD CONSTRAINT "pastoral_cares_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_cares" ADD CONSTRAINT "pastoral_cares_performed_by_id_fkey" FOREIGN KEY ("performed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_cares" ADD CONSTRAINT "pastoral_cares_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pastoral_cares" ADD CONSTRAINT "pastoral_cares_type_id_fkey" FOREIGN KEY ("type_id") REFERENCES "pastoral_care_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "request_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_assignee_id_fkey" FOREIGN KEY ("assignee_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "requests" ADD CONSTRAINT "requests_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "request_timeline_entries" ADD CONSTRAINT "request_timeline_entries_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "request_timeline_entries" ADD CONSTRAINT "request_timeline_entries_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "channel_posts" ADD CONSTRAINT "channel_posts_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "channel_post_audiences" ADD CONSTRAINT "channel_post_audiences_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "channel_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reads" ADD CONSTRAINT "post_reads_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "channel_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reads" ADD CONSTRAINT "post_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "channel_posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "credentials" ADD CONSTRAINT "credentials_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "credentials" ADD CONSTRAINT "credentials_issued_by_id_fkey" FOREIGN KEY ("issued_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "credentials" ADD CONSTRAINT "credentials_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_modules" ADD CONSTRAINT "training_modules_training_id_fkey" FOREIGN KEY ("training_id") REFERENCES "trainings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_enrollments" ADD CONSTRAINT "training_enrollments_training_id_fkey" FOREIGN KEY ("training_id") REFERENCES "trainings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_enrollments" ADD CONSTRAINT "training_enrollments_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_progress" ADD CONSTRAINT "training_progress_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "training_enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "training_progress" ADD CONSTRAINT "training_progress_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "training_modules"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "certificates" ADD CONSTRAINT "certificates_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "training_enrollments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_organizer_id_fkey" FOREIGN KEY ("organizer_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_participants" ADD CONSTRAINT "event_participants_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_participants" ADD CONSTRAINT "event_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_participants" ADD CONSTRAINT "event_participants_pastor_id_fkey" FOREIGN KEY ("pastor_id") REFERENCES "pastors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notification_devices" ADD CONSTRAINT "notification_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- =============================================================================
-- SQL manual: regras que o Prisma nao expressa no schema.
-- =============================================================================

-- Busca: trigram para "contem" case-insensitive sem full scan (ver docs/database.md).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS pastors_pastoral_name_trgm_idx ON pastors USING gin (pastoral_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS pastors_first_name_trgm_idx    ON pastors USING gin (first_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS pastors_last_name_trgm_idx     ON pastors USING gin (last_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS pastors_email_trgm_idx         ON pastors USING gin (email gin_trgm_ops);
CREATE INDEX IF NOT EXISTS churches_name_trgm_idx         ON churches USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS users_email_lower_idx          ON users (lower(email));

-- Hierarquia: no maximo UM supervisor ativo do tipo SUPERVISION por pastor.
CREATE UNIQUE INDEX IF NOT EXISTS pastoral_relationships_one_active_supervisor
  ON pastoral_relationships (subordinate_id)
  WHERE is_active = true AND type = 'SUPERVISION';

ALTER TABLE pastoral_relationships
  ADD CONSTRAINT pastoral_relationships_no_self CHECK (supervisor_id <> subordinate_id);

ALTER TABLE pastoral_closure
  ADD CONSTRAINT pastoral_closure_depth_non_negative CHECK (depth >= 0),
  ADD CONSTRAINT pastoral_closure_self_depth CHECK ((ancestor_id = descendant_id) = (depth = 0));

-- Integridade temporal e faixas.
ALTER TABLE events
  ADD CONSTRAINT events_ends_after_starts CHECK (ends_at >= starts_at);

ALTER TABLE training_enrollments
  ADD CONSTRAINT training_enrollments_progress_range CHECK (progress_pct BETWEEN 0 AND 100);

ALTER TABLE credentials
  ADD CONSTRAINT credentials_expiry_after_issue CHECK (expires_at IS NULL OR expires_at >= issued_at);

ALTER TABLE documents
  ADD CONSTRAINT documents_size_positive CHECK (size_bytes >= 0);

-- Participante de evento precisa referenciar usuario OU pastor.
ALTER TABLE event_participants
  ADD CONSTRAINT event_participants_target CHECK (user_id IS NOT NULL OR pastor_id IS NOT NULL);

-- Pendencias de cuidado: consulta frequente do dashboard do lider.
CREATE INDEX IF NOT EXISTS pastors_active_last_care_idx
  ON pastors (last_care_at NULLS FIRST)
  WHERE deleted_at IS NULL;
