<?php
// Excerpt of the code() handler of the user_oidc app, version 8.11.0, reduced to the lines the patch touches.
// Kept only as a test fixture; the real file is part of https://github.com/nextcloud/user_oidc (AGPL-3.0).
class LoginController {
	public function code() {
		// get user ID attribute
		$uidAttribute = $this->providerService->getSetting($providerId, ProviderService::SETTING_MAPPING_UID, 'sub');
		$userId = $this->provisioningService->getClaimValue($idTokenPayload, $uidAttribute, $providerId);

		if ($userId === null) {
			$this->cleanupSessionState($sessionKeySuffix);
			$message = $this->l10n->t('Failed to provision the user');
			return $this->build403TemplateResponse($message, Http::STATUS_BAD_REQUEST, ['reason' => 'failed to provision user']);
		}
	}
}
